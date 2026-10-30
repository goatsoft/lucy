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
	},
	AppState
))

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

-- Incoming tables may be reactive proxies; store their raw tables.
local function unwrap(value: any): any
	if type(value) == "table" and getmetatable(value) ~= nil then
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

local reconcile: (raw: { [any]: any }, incoming: { [any]: any }) -> boolean

-- Writes `value` at raw[key], reconciling into an existing table. Returns true if
-- anything changed. Notifies the key's readers; never copies an unchanged table.
local function assign(raw: { [any]: any }, key: any, value: any): boolean
	value = unwrap(value)
	local current = raw[key]
	if isPlain(value) then
		if isPlain(current) then
			return reconcile(current, value)
		end
		raw[key] = copyIn(value)
		Reactive._changedKey(raw, key, current == nil)
		return true
	end
	if sameValue(current, value) then
		return false
	end
	raw[key] = value
	Reactive._changedKey(raw, key, (current == nil) ~= (value == nil))
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
	for key in raw do
		if incoming[key] == nil then
			raw[key] = nil -- clearing a field during traversal is allowed
			Reactive._changedKey(raw, key, true)
			invalidate(raw, key)
			changed = true
		end
	end
	return changed
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
	Reactive._finish()

	self:_settle()
end

function AppState.set(self: AppState, path: string?, value: any)
	self:_write(split(path), value, false)
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

-- The value at `segments`, tracked: every key on the way (so replacing a parent
-- re-runs the reader), and the whole table when the path ends at one.
function AppState._tracked(self: AppState, segments: { any }): any
	local node: any = self._root
	for _, key in segments do
		if not isPlain(node) then
			return nil
		end
		Reactive._trackKey(node, key)
		node = node[key]
	end
	if isPlain(node) then
		Reactive._trackKey(node, VERSION)
		return snapshot(node)
	end
	return node
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
