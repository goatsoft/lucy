--!strict
--[[
	AppState: a synchronous, path-addressed store, built as a living tree (ADR 0004,
	amended by ADR 0017).

	The store holds plain tables and changes them in place: a write walks its path
	and costs O(depth), however big the tree is. Every key is a source in the
	reactive core, so effects and computeds that read the store re-run exactly
	when what they read changes.

	Reads hand out frozen snapshots. A table's snapshot is built when someone asks
	for it, cached until something under it changes, and reuses the snapshots of
	unchanged children: a value you read earlier never changes, and trying to
	mutate it throws.

	Paths are dot strings ("ui.playButton.disabled"); an all-digit segment is an
	array index ("toasts.1.title"). Subscribers are told when the value at their
	path changes, which includes changes to ancestors and descendants. They live
	on the path itself, so a write only visits the subscribers it can affect.

		local state = AppState.new({ ui = {} })
		local stop = state:subscribe("ui.play.disabled", function(new, old) end)
		state:set("ui.play.disabled", true)
		state:set("scenes.stack", { "Pause" }) -- reconciled by key: equal values notify nobody
		state:merge("ui.play", { text = "Go" })
		state:batch(function() ... end)       -- one notification per subscriber (same as Lucy.batch)
		stop()

		local coins = state:ref("player.coins") -- a writable ref onto the path's own source
		coins(coins() + 10)                     -- same as state:set("player.coins", ...)

		state.root.player.coins += 10           -- the tree as tables: tracked per key, writes
		for id, panel in state.root.ui do end   -- go through set, so everything above holds

	Values you set are copied in, so the store never shares a table with you.
	Tables with a metatable (handles, classes) are stored as opaque values.

	Components keep their props under "ui.<id>", the SceneManager under "scenes",
	toasts under "toasts" and the theme name under "theme". See docs/architecture.md.
]]

local Reactive = require(script.Parent.Reactive)

local AppState = {}
AppState.__index = AppState

-- A subscription. `pending` and `old` hold its place in the next notification.
type Subscriber = {
	path: string,
	segments: { any },
	fn: (new: any, old: any) -> (),
	alive: boolean,
	pending: boolean,
	old: any,
	seq: number,
	node: WatchNode,
}

-- One node of the subscription tree, which mirrors the paths people watch.
type WatchNode = {
	parent: WatchNode?,
	key: any,
	children: { [any]: WatchNode }?,
	subs: { Subscriber }?,
	total: number, -- subscribers here and below; a node at 0 is pruned
}

export type AppState = typeof(setmetatable(
	{} :: {
		_root: { [any]: any },
		_watch: WatchNode,
		_seq: number,
		_pending: { Subscriber },
		_spare: { Subscriber },
		_pendingCount: number,
		_flushing: boolean,
		_hooked: boolean,
		_afterBatch: () -> (),
		root: any,
	},
	AppState
))

-- Views handed out by `state.root` (defined below) keep their data under this
-- private key on the view itself. Not a weak map from view to data: the data
-- reaches the store, the store holds its root view, and a weak key that its own
-- value reaches is never collected.
type ProxyData = {
	store: AppState,
	segments: { any },
	children: { [any]: any },
	paths: { [any]: { any } },
}
local DATA = table.freeze({})

local function proxyData(value: any): ProxyData?
	return rawget(value, DATA)
end

-- The data of a value known to be a view.
local function dataOf(view: any): ProxyData
	return rawget(view, DATA) :: any
end

-- Paths --------------------------------------------------------------------------

local EMPTY = table.freeze({})
local MAX_CACHED_PATHS = 4096
local pathCache: { [string]: { any } } = {}
local cachedPaths = 0

-- Splits a dot path into segments (cached, frozen). All-digit segments become numbers.
local function split(path: string?): { any }
	if path == nil or path == "" then
		return EMPTY
	end
	local cached = pathCache[path :: string]
	if cached then
		return cached
	end
	local segments: { any } = string.split(path :: string, ".")
	for i, segment in segments do
		if segment == "" then
			error(`[Lucy] invalid state path "{path}"`, 3)
		end
		if string.match(segment, "^%d+$") then
			segments[i] = tonumber(segment)
		end
	end
	table.freeze(segments)
	cachedPaths += 1
	if cachedPaths > MAX_CACHED_PATHS then
		pathCache = {}
		cachedPaths = 1
	end
	pathCache[path :: string] = segments
	return segments
end

local function join(prefix: string, path: string?): string
	if path == nil or path == "" then
		return prefix
	end
	if prefix == "" then
		return path :: string
	end
	return prefix .. "." .. path
end

-- Values -------------------------------------------------------------------------

-- A table the store treats as a tree node: plain, no metatable.
local function isPlain(value: any): boolean
	return type(value) == "table" and getmetatable(value) == nil
end

--[[
	Snapshot cache per tree table. An entry remembers the last snapshot and which
	keys changed since (up to MAX_DIRTY), so the next snapshot is a native clone of
	the last one plus those keys. More changes than that, or an unknown one, rebuild
	it in full. Entries hold snapshots and keys, never the tree table itself, so the
	weak key can be collected once the table leaves the tree.
]]
type Entry = { snap: any, stale: boolean, full: boolean, dirty: { any }, count: number }
local MAX_DIRTY = 8
local entries: { [any]: Entry } = setmetatable({}, { __mode = "k" }) :: any

-- Readers of a table as a whole (state:ref onto a table) track this key.
local VERSION = table.freeze({})

local function snapshot(raw: { [any]: any }): any
	local entry = entries[raw]
	if entry and not entry.stale then
		return entry.snap
	end
	local snap
	if entry and not entry.full then
		snap = table.clone(entry.snap)
		local dirty = entry.dirty
		for i = 1, entry.count do
			local key = dirty[i]
			dirty[i] = nil
			local value = raw[key]
			snap[key] = if isPlain(value) then snapshot(value) else value
		end
	else
		-- Clone natively, then swap child tables for their (shared) snapshots.
		snap = table.clone(raw)
		for key, value in snap do
			if type(value) == "table" and getmetatable(value) == nil then
				snap[key] = snapshot(value)
			end
		end
		if entry then
			local dirty = entry.dirty
			for i = 1, entry.count do
				dirty[i] = nil
			end
		else
			entry = { snap = nil, stale = false, full = false, dirty = {}, count = 0 }
			entries[raw] = entry
		end
	end
	local e = entry :: Entry
	e.snap = table.freeze(snap)
	e.stale = false
	e.full = false
	e.count = 0
	return snap
end

local function valueOf(raw: any): any
	return if isPlain(raw) then snapshot(raw) else raw
end

-- True if `incoming` is the current snapshot of the tree table `raw`.
local function isSnapshotOf(raw: any, incoming: any): boolean
	local entry = entries[raw]
	return entry ~= nil and not entry.stale and rawequal(entry.snap, incoming)
end

-- Marks raw[key] changed (key nil: unknown): the snapshot is stale and readers of
-- the whole table re-run. Allocates nothing.
local function invalidate(raw: any, key: any)
	local entry = entries[raw]
	if entry then
		if not entry.full then
			local count = entry.count
			if key == nil or count >= MAX_DIRTY then
				entry.full = true
			elseif count == 0 or entry.dirty[count] ~= key then
				count += 1
				entry.count = count
				entry.dirty[count] = key
			end
		end
		entry.stale = true
	end
	Reactive._changedKey(raw, VERSION, false)
end

local function sameValue(a: any, b: any): boolean
	return a == b or (a ~= a and b ~= b) -- NaN equals NaN
end

-- Incoming tables may be proxies: a `state.root` proxy stands for its snapshot,
-- a reactive table for its raw table.
local function unwrap(value: any): any
	if type(value) == "table" and getmetatable(value) ~= nil then
		local view = proxyData(value)
		if view then
			return (view.store :: any):_read(view.segments)
		end
		return Reactive.toRaw(value)
	end
	return value
end

local equalValue: (current: any, incoming: any) -> boolean

-- True if the tree table `raw` holds exactly what `incoming` holds.
local function equalTable(raw: { [any]: any }, incoming: { [any]: any }): boolean
	local count = 0
	for key, value in incoming do
		count += 1
		local current = raw[key]
		if current ~= value then -- inline fast path; tables and NaN take the slow one
			if type(value) == "table" then
				if not equalValue(current, value) then
					return false
				end
			elseif value == value or current == current then
				return false
			end
		end
	end
	for _ in raw do
		count -= 1
	end
	return count == 0
end

equalValue = function(current: any, incoming: any): boolean
	incoming = unwrap(incoming)
	if isPlain(current) and isPlain(incoming) then
		return isSnapshotOf(current, incoming) or equalTable(current, incoming)
	end
	return sameValue(current, incoming)
end

-- A fresh tree table with the contents of `value` (a plain table or a snapshot).
local function copyIn(value: any): any
	value = unwrap(value)
	if not isPlain(value) then
		return value
	end
	local raw = {}
	for key, item in value do
		raw[key] = copyIn(item)
	end
	return raw
end

--[[
	Aliases (ADR 0017 section 5): a key bound to a writable ref. Any write to the
	key, from anywhere, writes the ref inside the same store write, before
	subscribers run. Writes are queued while the tree is mid-change and delivered
	right after it, so a ref setter that writes the store sees a whole tree.
]]
local aliases: { [any]: { [any]: any } } = setmetatable({}, { __mode = "k" }) :: any -- raw -> key -> ref
local aliasRefs: { any } = {}
local aliasRaws: { any } = {}
local aliasKeys: { any } = {}
local aliasCount = 0
local drainingAliases = false

local function queueAlias(raw: any, key: any)
	local bound = aliases[raw]
	local ref = bound and bound[key]
	if ref then
		aliasCount += 1
		aliasRefs[aliasCount] = ref
		aliasRaws[aliasCount] = raw
		aliasKeys[aliasCount] = key
	end
end

local reconcile: (raw: { [any]: any }, incoming: { [any]: any }) -> boolean

-- A table left the tree (removed, or replaced by a value): everyone reading a key
-- inside it runs again. Readers track only the key they read, not the tables
-- above it, so this is how they hear that the path is gone.
local function detach(raw: { [any]: any })
	Reactive._changedAll(raw)
	for _, value in raw do
		if isPlain(value) then
			detach(value)
		end
	end
end

-- Writes `value` at raw[key], reconciling into an existing table. Returns true if
-- anything changed. Notifies the key's readers; never copies an unchanged table.
local function assign(raw: { [any]: any }, key: any, value: any): boolean
	value = unwrap(value)
	local current = raw[key]
	if isPlain(value) then
		if isPlain(current) then
			if reconcile(current, value) then
				queueAlias(raw, key)
				return true
			end
			return false
		end
		raw[key] = copyIn(value)
		Reactive._changedKey(raw, key, current == nil)
		queueAlias(raw, key)
		return true
	end
	if sameValue(current, value) then
		return false
	end
	raw[key] = value
	Reactive._changedKey(raw, key, (current == nil) ~= (value == nil))
	if isPlain(current) then
		detach(current)
	end
	queueAlias(raw, key)
	return true
end

reconcile = function(raw: { [any]: any }, incoming: { [any]: any }): boolean
	if isSnapshotOf(raw, incoming) then
		return false
	end
	local changed = false
	for key, value in incoming do
		if assign(raw, key, value) then
			invalidate(raw, key)
			changed = true
		end
	end
	for key, old in raw do
		if incoming[key] == nil then
			raw[key] = nil -- clearing a field during traversal is allowed
			Reactive._changedKey(raw, key, true)
			if isPlain(old) then
				detach(old)
			end
			invalidate(raw, key)
			queueAlias(raw, key)
			changed = true
		end
	end
	return changed
end

local function writeRef(ref: any, value: any)
	if ref() ~= value then
		ref(value)
	end
end

-- Writes queued aliases: each ref gets its key's current value (a snapshot for a
-- table). A ref that already holds it is not written, so nothing ping-pongs.
local function drainAliases()
	if drainingAliases then
		return -- the outer drain picks up aliases queued meanwhile
	end
	drainingAliases = true
	local i = 1
	while i <= aliasCount do
		local ref, raw, key = aliasRefs[i], aliasRaws[i], aliasKeys[i]
		aliasRefs[i], aliasRaws[i], aliasKeys[i] = nil, nil, nil
		i += 1
		local value = raw[key]
		if isPlain(value) then
			value = snapshot(value)
		end
		local ok: boolean, err: any = pcall(Reactive._untracked, writeRef, ref, value)
		if not ok then
			warn(`[Lucy] writing a bound ref failed: {err}`)
		end
	end
	aliasCount = 0
	drainingAliases = false
end

-- The table at the first `count` segments, or nil. Tracks only the key where the
-- path stops, so the reader runs again when the missing table appears. The tables
-- on the way are not tracked: one that leaves the tree notifies its readers
-- (`detach`), and one that is set again is updated in place.
local function walk(root: any, segments: { any }, count: number): any
	local node = root
	for i = 1, count do
		local key = segments[i]
		local child = node[key]
		if not isPlain(child) then
			Reactive._trackKey(node, key)
			return nil
		end
		node = child
	end
	return node
end

-- The raw value at `segments`, or nil if the path runs through a non-table.
local function readRaw(root: any, segments: { any }): any
	local node = root
	for _, key in segments do
		if not isPlain(node) then
			return nil
		end
		node = node[key]
	end
	return node
end

-- state.root --------------------------------------------------------------------------
--[[
	A view of the tree as tables. Reads are tracked per key (a table read returns
	another view, cached while in use); `#` and iteration track the whole table.
	Assignments are `set` on the matching path, so they reconcile, notify
	subscribers and keep snapshots right. Views are addressed by path.
]]
local proxyMeta: { [string]: any } = {}

local function newProxy(store: AppState, segments: { any }): any
	local data: ProxyData = {
		store = store,
		segments = segments,
		children = setmetatable({}, { __mode = "v" }) :: any,
		paths = {},
	}
	return setmetatable({ [DATA] = data }, proxyMeta)
end

local function childPath(data: ProxyData, key: any): { any }
	local path = data.paths[key]
	if not path then
		local segments = table.clone(data.segments)
		table.insert(segments, key)
		path = table.freeze(segments)
		data.paths[key] = path
	end
	return path :: { any }
end

-- The tree table a view stands for; nil if gone.
local function viewNode(data: ProxyData): any
	return walk(data.store._root, data.segments, #data.segments)
end

local function childView(data: ProxyData, key: any): any
	local child = data.children[key]
	if not child then
		child = newProxy(data.store, childPath(data, key))
		data.children[key] = child
	end
	return child
end

function proxyMeta.__index(proxy: any, key: any): any
	local data = dataOf(proxy)
	local node = viewNode(data)
	if node == nil then
		return nil
	end
	Reactive._trackKey(node, key)
	local value = node[key]
	if isPlain(value) then
		return childView(data, key)
	end
	return value
end

function proxyMeta.__newindex(proxy: any, key: any, value: any)
	local data = dataOf(proxy)
	data.store:_write(childPath(data, key), value, false)
end

function proxyMeta.__len(proxy: any): number
	local node = viewNode(dataOf(proxy))
	if node == nil then
		return 0
	end
	Reactive._trackKey(node, VERSION)
	return #node
end

function proxyMeta.__iter(proxy: any)
	local data = dataOf(proxy)
	local node = viewNode(data)
	if node == nil then
		return function(): any
			return nil
		end
	end
	Reactive._trackKey(node, VERSION)
	return function(_, key): (any, any)
		local nextKey, value = next(node, key)
		if nextKey ~= nil and isPlain(value) then
			return nextKey, childView(data, nextKey)
		end
		return nextKey, value
	end
end

function proxyMeta.__tostring(proxy: any): string
	local path = table.concat(dataOf(proxy).segments, ".")
	return `AppState.root({path})`
end

-- Notification ---------------------------------------------------------------------

local function bySeq(a: Subscriber, b: Subscriber): boolean
	return a.seq < b.seq
end

-- Queues every subscriber on `node` with `old`, unless it is already queued (then
-- it keeps the older value and reads the newest when it runs).
local function markSubs(self: AppState, node: WatchNode, old: any)
	local subs = node.subs
	if not subs then
		return
	end
	for _, sub in subs do
		if not sub.pending then
			sub.pending = true
			sub.old = old
			local count = self._pendingCount + 1
			self._pendingCount = count
			self._pending[count] = sub
		end
	end
end

-- Queues subscribers on `node` and every watched path under it.
local function markDown(self: AppState, node: WatchNode, raw: any)
	if node.subs then
		markSubs(self, node, valueOf(raw))
	end
	local children = node.children
	if children then
		local isTable = isPlain(raw)
		for key, child in children do
			markDown(self, child, if isTable then raw[key] else nil)
		end
	end
end

function AppState.new(initial: { [string]: any }?): AppState
	local self = setmetatable({
		_root = if initial then copyIn(initial) else {},
		_watch = { total = 0, key = nil, parent = nil } :: WatchNode,
		_seq = 0,
		_pending = {} :: { Subscriber },
		_spare = {} :: { Subscriber },
		_pendingCount = 0,
		_flushing = false,
		_hooked = false,
		_afterBatch = function() end,
	}, AppState)
	self._afterBatch = function()
		self._hooked = false
		self:_flush()
	end
	self.root = newProxy(self, EMPTY)
	return self
end

-- The value at `segments`: plain values as they are, tables as frozen snapshots.
function AppState._read(self: AppState, segments: { any }): any
	return valueOf(readRaw(self._root, segments))
end

function AppState.get(self: AppState, path: string?): any
	return self:_read(split(path))
end

-- Queues the subscribers a write at `segments` can affect: those on ancestors
-- (with their snapshot from before the write), on the path, and below it.
function AppState._mark(self: AppState, segments: { any })
	local depth = #segments
	local node: WatchNode = self._watch
	if node.total == 0 then
		return
	end
	local raw: any = self._root
	local i = 0
	while true do
		if i == depth then
			markDown(self, node, raw)
			return
		end
		if node.subs then
			markSubs(self, node, valueOf(raw))
		end
		local children = node.children
		if not children then
			return
		end
		i += 1
		local key = segments[i]
		local child = children[key]
		if not child then
			return
		end
		node = child
		raw = if isPlain(raw) then raw[key] else nil
	end
end

-- Calls queued subscribers in subscription order. A write made by a subscriber
-- queues its own round, delivered after this one.
function AppState._flush(self: AppState)
	if self._flushing then
		return
	end
	self._flushing = true
	while self._pendingCount > 0 do
		local list, count = self._pending, self._pendingCount
		self._pending, self._pendingCount = self._spare, 0
		if count > 1 then
			table.sort(list, bySeq) -- entries past `count` are nil, so #list == count
		end
		for i = 1, count do
			local sub = list[i]
			list[i] = nil
			sub.pending = false
			local old = sub.old
			sub.old = nil
			if sub.alive then
				local new = self:_read(sub.segments)
				if new ~= old then
					local ok: boolean, err: any = pcall(sub.fn, new, old)
					if not ok then
						warn(`[Lucy] state subscriber for "{sub.path}" errored: {err}`)
					end
				end
			end
		end
		self._spare = list
	end
	self._flushing = false
end

-- Runs or defers the queued notifications: inside Lucy.batch / state:batch they
-- wait for the batch to end.
function AppState._settle(self: AppState)
	if self._pendingCount == 0 then
		return
	end
	if Reactive._inBatch() then
		if not self._hooked then
			self._hooked = true
			Reactive._afterBatch(self._afterBatch)
		end
		return
	end
	self:_flush()
end

--[[
	The one write path. `merge` shallow-merges a patch into the table at the path
	instead of replacing it. Equal values change nothing and notify nobody.
]]
function AppState._write(self: AppState, segments: { any }, value: any, merge: boolean)
	local current = readRaw(self._root, segments)
	if merge then
		if isPlain(current) then
			local same = true
			for key, item in value do
				if not equalValue(current[key], item) then
					same = false
					break
				end
			end
			if same then
				return
			end
		end
	elseif equalValue(current, value) then
		return
	end

	local depth = #segments
	if depth == 0 and not merge and not isPlain(unwrap(value)) then
		error("[Lucy] the state root must be a table", 3)
	end

	self:_mark(segments)

	Reactive._begin()
	local raw = self._root
	if depth == 0 then
		if merge then
			for key, item in value do
				if assign(raw, key, item) then
					invalidate(raw, key)
				end
			end
		else
			reconcile(raw, unwrap(value))
		end
	else
		-- Every table on the path changes at the next key down.
		for i = 1, depth - 1 do
			local key = segments[i]
			invalidate(raw, key)
			local child = raw[key]
			if not isPlain(child) then
				child = {}
				raw[key] = child
				Reactive._changedKey(raw, key, true)
			end
			raw = child
		end
		local key = segments[depth]
		invalidate(raw, key)
		if merge then
			local target = raw[key]
			if not isPlain(target) then
				target = {}
				raw[key] = target
				Reactive._changedKey(raw, key, true)
			end
			for patchKey, item in value do
				if assign(target, patchKey, item) then
					invalidate(target, patchKey)
				end
			end
		else
			assign(raw, key, value)
		end
	end
	if aliasCount > 0 then
		drainAliases()
	end
	Reactive._finish()

	self:_settle()
end

function AppState.set(self: AppState, path: string?, value: any)
	self:_write(split(path), value, false)
end

-- Internal, for component handles (ADR 0017 section 5): pre-split paths, so a
-- handle never parses a path again.
function AppState._segments(_self: AppState, path: string?): { any }
	return split(path)
end

-- The value at `key` of the table at `segments` (a snapshot for a table). No allocation.
function AppState._readKey(self: AppState, segments: { any }, key: any): any
	local node = readRaw(self._root, segments)
	if not isPlain(node) then
		return nil
	end
	return valueOf(node[key])
end

-- `_readKey`, tracked: re-runs the reader when that key or a table above it changes.
-- The second result says whether the table at `segments` exists.
function AppState._trackedKey(self: AppState, segments: { any }, key: any): (any, boolean)
	local node = walk(self._root, segments, #segments)
	if node == nil then
		return nil, false
	end
	Reactive._trackKey(node, key)
	return valueOf(node[key]), true
end

-- Binds `key` of the table at `segments` to a writable ref. Returns the unbind.
function AppState._alias(self: AppState, segments: { any }, key: any, ref: any): () -> ()
	local node = readRaw(self._root, segments)
	if not isPlain(node) then
		error("[Lucy] can only bind a key of an existing table", 2)
	end
	local bound = aliases[node]
	if not bound then
		bound = {}
		aliases[node] = bound
	end
	(bound :: any)[key] = ref
	return function()
		local current = aliases[node]
		if current and current[key] == ref then
			current[key] = nil
			if next(current) == nil then
				aliases[node] = nil
			end
		end
	end
end

function AppState.update(self: AppState, path: string?, fn: (any) -> any)
	local segments = split(path)
	self:_write(segments, fn(self:_read(segments)), false)
end

-- Shallow-merges `patch` into the table at `path`; only writes when something differs.
function AppState.merge(self: AppState, path: string?, patch: { [string]: any })
	self:_write(split(path), patch, true)
end

function AppState.remove(self: AppState, path: string)
	self:_write(split(path), nil, false)
end

function AppState.subscribe(self: AppState, path: string?, fn: (new: any, old: any) -> ()): () -> ()
	local segments = split(path)
	local node: WatchNode = self._watch
	for _, key in segments do
		local children = node.children
		if not children then
			children = {}
			node.children = children
		end
		local child = (children :: { [any]: WatchNode })[key]
		if not child then
			child = { parent = node, key = key, total = 0 } :: WatchNode
			(children :: { [any]: WatchNode })[key] = child
		end
		node = child :: WatchNode
	end
	self._seq += 1
	local sub: Subscriber = {
		path = path or "",
		segments = segments,
		fn = fn,
		alive = true,
		pending = false,
		old = nil,
		seq = self._seq,
		node = node,
	}
	local subs = node.subs
	if subs then
		table.insert(subs, sub)
	else
		node.subs = { sub }
	end
	local walk: WatchNode? = node
	while walk do
		walk.total += 1
		walk = walk.parent
	end

	return function()
		if not sub.alive then
			return
		end
		sub.alive = false -- a queued notification for it is skipped
		local list = sub.node.subs
		if list then
			local index = table.find(list, sub)
			if index then
				table.remove(list, index)
			end
			if #list == 0 then
				sub.node.subs = nil
			end
		end
		local at: WatchNode? = sub.node
		while at do
			at.total -= 1
			local parent = at.parent
			if at.total == 0 and parent and parent.children then
				parent.children[at.key] = nil
				if next(parent.children) == nil then
					parent.children = nil
				end
			end
			at = parent
		end
	end
end

-- The value at `segments`, tracked: the whole table when the path ends at one,
-- else the last key.
function AppState._tracked(self: AppState, segments: { any }): any
	local depth = #segments
	local node: any = self._root
	if depth > 0 then
		local parent = walk(node, segments, depth - 1)
		if parent == nil then
			return nil
		end
		local key = segments[depth]
		node = parent[key]
		if not isPlain(node) then
			Reactive._trackKey(parent, key)
			return node
		end
	end
	Reactive._trackKey(node, VERSION)
	return snapshot(node)
end

--[[
	A writable ref onto `path`. It reads the path's own sources (tracked, no
	subscription and no mirror ref) and writes the path. It costs what a ref costs.
]]
function AppState.ref(self: AppState, path: string?): Reactive.Ref<any>
	local segments = split(path)
	return Reactive.computed({
		get = function()
			return self:_tracked(segments)
		end,
		set = function(new: any)
			self:_write(segments, new, false)
		end,
	}) :: any
end

-- Runs `fn` and delivers at most one notification per subscriber afterwards. The
-- same as Lucy.batch: effects and store subscribers both wait for the end.
function AppState.batch(_self: AppState, fn: () -> ())
	Reactive.batch(fn)
end

-- A view of the store with every path prefixed, so a component can own "ui.<id>".
function AppState.scope(self: AppState, prefix: string): any
	local store = self
	local scoped: any = {}
	function scoped:get(path)
		return store:get(join(prefix, path))
	end
	function scoped:set(path, value)
		store:set(join(prefix, path), value)
	end
	function scoped:update(path, fn)
		store:update(join(prefix, path), fn)
	end
	function scoped:merge(path, patch)
		store:merge(join(prefix, path), patch)
	end
	function scoped:remove(path)
		store:remove(join(prefix, path))
	end
	function scoped:subscribe(path, fn)
		return store:subscribe(join(prefix, path), fn)
	end
	function scoped:batch(fn)
		store:batch(fn)
	end
	function scoped:scope(inner)
		return store:scope(join(prefix, inner))
	end
	function scoped:ref(path)
		return store:ref(join(prefix, path))
	end
	return scoped
end

local function killAll(node: WatchNode)
	if node.subs then
		for _, sub in node.subs do
			sub.alive = false
		end
	end
	if node.children then
		for _, child in node.children do
			killAll(child)
		end
	end
end

function AppState.destroy(self: AppState)
	killAll(self._watch)
	self._watch = { total = 0, key = nil, parent = nil } :: WatchNode
end

return AppState
