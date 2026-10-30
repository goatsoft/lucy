--!strict
--[[
	Reactive: Lucy's fine-grained reactivity (ADR 0014), in plain Luau call
	syntax: a ref is a function, call it to read, call it with a value to write.
	No `.value`, no unwrapping magic.

		local count = Lucy.ref(0)
		count()                      --> 0, tracked inside computed / watchEffect
		count(5)                     write; dependents update once, glitch-free

		local double = Lucy.computed(function() return count() * 2 end)
		local name = Lucy.computed({ get = function() ... end, set = function(v) ... end })

		local player = Lucy.reactive({ coins = 0, bag = {} })
		player.coins += 1            tracked per key, nested tables too
		Lucy.insert(player.bag, "sword") ; Lucy.remove(player.bag, 1)

		Lucy.watchEffect(function(onCleanup) print(count()) end)
		Lucy.watch(count, function(new, old, onCleanup) end, { immediate = true })
		Lucy.batch(function() a(1) b(2) end)       dependents run once, after
		Lucy.untrack(fn) ; Lucy.peek(source) ; Lucy.toValue(refOrGetterOrValue)
		local scope = Lucy.effectScope() ; scope:run(fn) ; scope:stop()
		Lucy.onCleanup(fn)           runs when the current effect re-runs or its scope stops

	How it works: refs and reactive keys are sources; computeds and effects observe
	them. A write marks direct observers DIRTY and everything downstream CHECK.
	Effects then refresh: a CHECK node re-validates its computed sources first and
	only re-runs if one of them actually changed value. Computeds are lazy and
	cached; nothing re-renders, only the exact bindings that changed run again.
]]

export type Ref<T> = (() -> T) & ((value: T) -> ())
export type Computed<T> = () -> T
export type MaybeRef<T> = T | () -> T
export type StopHandle = () -> ()
export type OnCleanup = (cleanup: () -> ()) -> ()
export type Scope = {
	active: boolean,
	run: (self: Scope, fn: (...any) -> ...any, ...any) -> ...any,
	stop: (self: Scope) -> (),
	onCleanup: (self: Scope, cleanup: () -> ()) -> (),
}
export type WatchOptions = { immediate: boolean?, deep: boolean? }

local CLEAN, CHECK, DIRTY = 0, 1, 2
local MAX_ROUNDS = 100

local Reactive = {}

local tracking: any = nil -- the computed / effect collecting sources right now
local owner: any = nil -- the node that owns new effects, scopes and cleanups
local batchDepth = 0
-- Effects waiting to run, double-buffered so flushing never allocates. Indexed by
-- count, never iterated with `for in` or cleared with table.clear: both cost the
-- buffer's capacity, which stays large after one big flush.
local queue: { any } = {}
local spare: { any } = {}
local queueSize = 0
local flushing = false
-- Lucy.batch depth (not the internal one), and callbacks to run when it ends.
-- AppState uses this so its subscribers are batched by Lucy.batch too (ADR 0017).
local userBatch = 0
local endHooks: { () -> () } = {}
local endHookCount = 0
local runningHooks = false

local nodeOf: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any -- accessor -> node

local function defaultEquals(a: any, b: any): boolean
	return a == b or (a ~= a and b ~= b) -- NaN equals NaN
end

local function never(): boolean
	return false
end

local function report(err: any)
	task.spawn(error, err, 0)
end

-- Nodes carry only the tables their kind uses: refs and keys are observed,
-- effects observe, computeds do both, scopes do neither.
-- (One literal per kind, so the table is sized once.)
local function newNode(kind: string): any
	if kind == "effect" then
		return { kind = kind, state = CLEAN, sources = {} }
	elseif kind == "computed" then
		return { kind = kind, state = CLEAN, sources = {}, observers = {} }
	elseif kind == "scope" then
		return { kind = kind, state = CLEAN }
	end
	return { kind = kind, state = CLEAN, observers = {} }
end

local function addCleanup(node: any, cleanup: () -> ())
	local cleanups = node.cleanups
	if cleanups then
		table.insert(cleanups, cleanup)
	else
		node.cleanups = { cleanup }
	end
end

local function adopt(node: any)
	local o = owner
	if o then
		node.owner = o
		local children = o.children
		if children then
			children[node] = true
		else
			o.children = { [node] = true }
		end
	end
end

-- `execute` unlinks a node before running it, so `observers[t]` doubles as the
-- seen-this-run check and tracking allocates nothing.
local function track(source: any)
	local t = tracking
	if t ~= nil and not t.disposed then
		local observers = source.observers
		if not observers[t] then
			observers[t] = true
			table.insert(t.sources, source)
		end
	end
end

local function unlink(node: any)
	local sources = node.sources
	if sources == nil then
		return
	end
	for _, source in sources do
		source.observers[node] = nil
	end
	table.clear(sources)
end

local dispose: (node: any) -> ()

-- Runs cleanups and disposes owned children (effects, computeds, scopes).
local function release(node: any)
	local children = node.children
	if children then
		node.children = nil
		for child in children do
			dispose(child)
		end
	end
	local cleanups = node.cleanups
	if cleanups then
		node.cleanups = nil
		for i = #cleanups, 1, -1 do
			local ok, err = pcall(cleanups[i])
			if not ok then
				report(err)
			end
		end
	end
end

dispose = function(node: any)
	if node.disposed then
		return
	end
	node.disposed = true
	release(node)
	unlink(node)
	local o = node.owner
	if o then
		node.owner = nil
		if o.children then
			o.children[node] = nil
		end
	end
end

local function schedule(effect: any)
	if not effect.queued then
		effect.queued = true
		queueSize += 1
		queue[queueSize] = effect
	end
end

local function mark(node: any, state: number)
	if node.state >= state then
		return
	end
	local wasClean = node.state == CLEAN
	node.state = state
	if node.kind == "effect" then
		schedule(node)
	elseif wasClean then
		for observer in node.observers do
			mark(observer, CHECK)
		end
	end
end

local refresh: (node: any) -> ()

local function flush()
	if flushing then
		return
	end
	flushing = true
	local rounds = 0
	while queueSize > 0 do
		rounds += 1
		if rounds > MAX_ROUNDS then
			for i = 1, queueSize do
				local effect = queue[i]
				queue[i] = nil
				effect.queued = false
				effect.state = CLEAN
			end
			queueSize = 0
			report(
				"[Lucy] effects kept re-triggering each other; is a watchEffect writing to a ref another one reads?"
			)
			break
		end
		local current, count = queue, queueSize
		queue, queueSize = spare, 0
		for i = 1, count do
			local effect = current[i]
			current[i] = nil
			effect.queued = false -- false, not nil: keeps the key so the node never rehashes
			if not effect.disposed then
				local ok: boolean, err: any = pcall(refresh, effect)
				if not ok then
					effect.state = CLEAN
					report(err)
				end
			end
		end
		spare = current
	end
	flushing = false
end

local function notify(observers: { [any]: boolean })
	batchDepth += 1
	for observer in observers do
		mark(observer, DIRTY)
	end
	batchDepth -= 1
	if batchDepth == 0 then
		flush()
	end
end

-- Runs a computed / effect body, collecting its sources and owned children afresh.
local function execute(node: any, ...): (boolean, any)
	release(node)
	unlink(node)
	local previousTracking, previousOwner = tracking, owner
	tracking, owner = node, node
	local ok, result = pcall(node.fn, ...)
	tracking, owner = previousTracking, previousOwner
	return ok, result
end

local function recompute(node: any)
	local ok, result = execute(node, node.value)
	node.state = CLEAN
	if not ok then
		node.err = result
		node.initialized = false
		error(result, 0)
	end
	node.err = nil
	if node.initialized and node.equals(node.value, result) then
		return
	end
	node.initialized = true
	node.value = result
	for observer in node.observers do
		if observer.state == CLEAN then
			mark(observer, DIRTY)
		else
			observer.state = DIRTY
		end
	end
end

local function runEffect(node: any)
	local ok, err = execute(node, node.onCleanup)
	node.state = CLEAN
	if not ok then
		report(err)
	end
end

refresh = function(node: any)
	if node.disposed then
		return
	end
	if node.state == CHECK then
		for _, source in node.sources do
			if source.kind == "computed" then
				if not pcall(refresh, source) then
					node.state = DIRTY -- re-run so the error surfaces where it is read
				end
				if node.state == DIRTY then
					break
				end
			end
		end
	end
	if node.state == DIRTY then
		if node.kind == "computed" then
			recompute(node)
		else
			runEffect(node)
		end
	else
		node.state = CLEAN
	end
end

-- Refs ---------------------------------------------------------------------------

function Reactive.ref<T>(initial: T, options: { equals: ((T, T) -> boolean)? }?): Ref<T>
	local node = newNode("ref")
	node.value = initial
	local equals: (any, any) -> boolean = (options and options.equals) or defaultEquals :: any
	local function accessor(...)
		if select("#", ...) == 0 then
			track(node)
			return node.value
		end
		local value = ...
		if equals(node.value, value) then
			return
		end
		node.value = value
		notify(node.observers)
		return
	end
	nodeOf[accessor] = node
	return accessor :: any
end

-- Notifies a ref's dependents after mutating its table in place.
function Reactive.trigger(source: any)
	local node = nodeOf[source]
	if node and node.kind == "ref" then
		notify(node.observers)
	end
end

-- Computeds ------------------------------------------------------------------------

function Reactive.computed<T>(
	getter: ((previous: T?) -> T) | { get: (previous: T?) -> T, set: (value: T) -> () },
	options: { equals: ((T, T) -> boolean)? }?
): Computed<T>
	local get, set
	if type(getter) == "table" then
		get, set = getter.get, getter.set
	else
		get = getter
	end
	assert(type(get) == "function", "[Lucy] computed needs a getter function or { get = ..., set = ... }")
	if nodeOf[get] then
		-- computed(someRef): never pass `previous` to a ref, it would write it
		local source = get
		get = function()
			return source()
		end
	end
	local node = newNode("computed")
	node.fn = get
	node.writable = set ~= nil
	node.state = DIRTY
	node.equals = (options and options.equals) or defaultEquals
	adopt(node)
	local function accessor(...)
		if select("#", ...) > 0 then
			if not set then
				error(
					"[Lucy] this computed is read-only; pass { get = ..., set = ... } to make it writable",
					2
				)
			end
			set((...))
			return nil
		end
		if node.disposed then
			return Reactive.untrack(get, node.value)
		end
		pcall(refresh, node) -- a failing getter leaves node.err; track first so we hear the fix
		track(node)
		if node.err ~= nil then
			error(node.err, 0)
		end
		return node.value
	end
	nodeOf[accessor] = node
	return accessor :: any
end

-- Effects ---------------------------------------------------------------------------

function Reactive.watchEffect(fn: (onCleanup: OnCleanup) -> ()): StopHandle
	local node = newNode("effect")
	node.fn = fn
	node.onCleanup = function(cleanup: () -> ())
		addCleanup(node, cleanup)
	end
	adopt(node)
	node.state = DIRTY
	batchDepth += 1
	local ok: boolean, err: any = pcall(refresh, node)
	batchDepth -= 1
	if not ok then
		report(err)
	end
	if batchDepth == 0 then
		flush()
	end
	return function()
		dispose(node)
	end
end

local function traverse(value: any, seen: { [any]: boolean })
	if type(value) ~= "table" or seen[value] then
		return
	end
	seen[value] = true
	for key in value do
		traverse(value[key], seen)
	end
end

local function shallowArrayEquals(a: { any }, b: { any }): boolean
	if #a ~= #b then
		return false
	end
	for i, value in a do
		if not defaultEquals(value, b[i]) then
			return false
		end
	end
	return true
end

local raws: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any -- proxy -> raw

function Reactive.watch(
	source: any,
	callback: (new: any, old: any, onCleanup: OnCleanup) -> (),
	options: WatchOptions?
): StopHandle
	local opts: WatchOptions = options or {}
	local getter: () -> any
	local equals: (any, any) -> boolean = defaultEquals
	local deep = opts.deep == true
	if type(source) == "function" and not deep then
		-- The common case, one effect and no hidden computed: it may re-run with an
		-- equal value (a getter whose inputs changed), which is skipped here, so the
		-- callback's cleanups are kept apart from the effect's own.
		local immediate = opts.immediate == true
		local initialized, old = false, nil
		local cleanups: { () -> () }? = nil
		local function onCleanup(cleanup: () -> ())
			if cleanups then
				table.insert(cleanups, cleanup)
			else
				cleanups = { cleanup }
			end
		end
		local function runCleanups()
			local list = cleanups
			cleanups = nil
			if list then
				for i = #list, 1, -1 do
					local ok: boolean, err: any = pcall(list[i] :: any)
					if not ok then
						report(err)
					end
				end
			end
		end
		local stopEffect = Reactive.watchEffect(function()
			local new = source()
			if not initialized then
				initialized = true
				old = new
				if immediate then
					Reactive._untracked(callback, new, nil, onCleanup)
				end
				return
			end
			if defaultEquals(new, old) then
				return
			end
			local previous = old
			old = new
			runCleanups()
			Reactive._untracked(callback, new, previous, onCleanup) -- no allocation per change
		end)
		Reactive.onCleanup(runCleanups) -- the owner stopping ends the watch too
		return function()
			stopEffect()
			runCleanups()
		end
	end
	if type(source) == "function" then
		getter = function()
			return source()
		end
	elseif raws[source] ~= nil then
		getter = function()
			return source
		end
		deep = opts.deep ~= false
	elseif type(source) == "table" then
		getter = function()
			local out = table.create(#source)
			for i, item in source do
				out[i] = Reactive.toValue(item)
			end
			return out
		end
		equals = shallowArrayEquals
	else
		error("[Lucy] watch needs a ref, computed, getter, reactive table or an array of them", 2)
	end
	if deep then
		local base = getter
		getter = function()
			local value = base()
			traverse(value, {})
			return value
		end
		equals = never
	end

	local value = Reactive.computed(getter, { equals = equals })
	local initialized, old = false, nil
	local stop = Reactive.watchEffect(function(onCleanup)
		local new = value()
		if not initialized then
			initialized = true
			if not opts.immediate then
				old = new
				return
			end
		end
		local previous = old
		old = new
		Reactive._untracked(callback, new, previous, onCleanup) -- no allocation per change
	end)
	return function()
		stop()
		dispose(nodeOf[value])
	end
end

-- Ownership --------------------------------------------------------------------------

-- Registers `cleanup` on the current effect or scope. Returns false if there is none.
function Reactive.onCleanup(cleanup: () -> ()): boolean
	if owner then
		addCleanup(owner, cleanup)
		return true
	end
	return false
end

local scopeMethods = {}

function scopeMethods.run(scope: any, fn: (...any) -> ...any, ...): ...any
	local node = scope._node
	if node.disposed then
		error("[Lucy] this effect scope has been stopped", 2)
	end
	local previousOwner = owner
	owner = node
	local results = table.pack(pcall(fn, ...))
	owner = previousOwner
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

function scopeMethods.stop(scope: any)
	dispose(scope._node)
end

function scopeMethods.onCleanup(scope: any, cleanup: () -> ())
	addCleanup(scope._node, cleanup)
end

local scopeMeta = {
	__index = function(scope: any, key: any): any
		if key == "active" then
			return not scope._node.disposed
		end
		return scopeMethods[key]
	end,
}

-- A group of effects stopped together. Child of the current scope unless `detached`.
function Reactive.effectScope(detached: boolean?): Scope
	local node = newNode("scope")
	if not detached then
		adopt(node)
	end
	-- One small table per scope; the methods are shared (every element has a scope).
	return setmetatable({ _node = node }, scopeMeta) :: any
end

-- Reading helpers --------------------------------------------------------------------

local function runEndHooks()
	if runningHooks then
		return -- the outer runner picks up hooks added meanwhile
	end
	runningHooks = true
	local i = 1
	while i <= endHookCount do
		local hook = endHooks[i]
		endHooks[i] = nil
		i += 1
		local ok: boolean, err: any = pcall(hook :: any)
		if not ok then
			report(err)
		end
	end
	endHookCount = 0
	runningHooks = false
end

function Reactive.batch<R...>(fn: (...any) -> R..., ...): R...
	batchDepth += 1
	userBatch += 1
	local results = table.pack(pcall(fn, ...))
	userBatch -= 1
	batchDepth -= 1
	if batchDepth == 0 then
		flush()
	end
	if userBatch == 0 and endHookCount > 0 then
		runEndHooks()
	end
	if not results[1] then
		error(results[2], 0)
	end
	return (table.unpack :: any)(results, 2, results.n)
end

function Reactive.untrack<R...>(fn: (...any) -> R..., ...): R...
	local previous = tracking
	tracking = nil
	local results = table.pack(pcall(fn, ...))
	tracking = previous
	if not results[1] then
		error(results[2], 0)
	end
	return (table.unpack :: any)(results, 2, results.n)
end

-- A value, ref, computed or getter, read as a plain value (tracked).
function Reactive.toValue<T>(source: MaybeRef<T>): T
	if type(source) == "function" then
		return (source :: any)()
	end
	return source :: T
end

-- toValue without subscribing.
function Reactive.peek<T>(source: MaybeRef<T>): T
	return Reactive.untrack(Reactive.toValue, source)
end

function Reactive.isRef(value: any): boolean
	return type(value) == "function" and nodeOf[value] ~= nil
end

-- True for a ref or a computed made with { get, set }: calling it with a value writes.
function Reactive.isWritable(value: any): boolean
	if type(value) ~= "function" then
		return false
	end
	local node = nodeOf[value]
	return node ~= nil and (node.kind == "ref" or node.writable == true)
end

-- Reactive tables ----------------------------------------------------------------------

local proxies: { [any]: any } = setmetatable({}, { __mode = "kv" }) :: any -- raw -> proxy
local keyNodes: { [any]: { [any]: any } } = setmetatable({}, { __mode = "k" }) :: any -- raw -> key -> node
local ITERATE = table.freeze({})

local function keyNode(raw: any, key: any): any
	local map = keyNodes[raw]
	if not map then
		map = {}
		keyNodes[raw] = map
	end
	local node = map[key]
	if not node then
		node = newNode("key")
		map[key] = node
	end
	return node
end

local function wrap(value: any): any
	if type(value) == "table" and getmetatable(value) == nil and not table.isfrozen(value) then
		return Reactive.reactive(value)
	end
	return value
end

local function unwrap(value: any): any
	return if type(value) == "table" then raws[value] or value else value
end

-- Notifies key observers: `keys` are exact keys; `from` notifies numeric keys >= from.
local function changed(raw: any, key: any, structural: boolean, from: number?)
	local map = keyNodes[raw]
	if not map then
		return
	end
	batchDepth += 1
	if from then
		for k, node in map do
			if type(k) == "number" and k >= from then
				for observer in node.observers do
					mark(observer, DIRTY)
				end
			end
		end
	elseif map[key] then
		for observer in map[key].observers do
			mark(observer, DIRTY)
		end
	end
	if structural and map[ITERATE] then
		for observer in map[ITERATE].observers do
			mark(observer, DIRTY)
		end
	end
	batchDepth -= 1
	if batchDepth == 0 then
		flush()
	end
end

local proxyMeta = {}

function proxyMeta.__index(proxy: any, key: any): any
	local raw = raws[proxy]
	if tracking then
		track(keyNode(raw, key))
	end
	return wrap(raw[key])
end

function proxyMeta.__newindex(proxy: any, key: any, value: any)
	local raw = raws[proxy]
	value = unwrap(value)
	local old = raw[key]
	if rawequal(old, value) then
		return
	end
	raw[key] = value
	changed(raw, key, (old == nil) ~= (value == nil), nil)
end

function proxyMeta.__len(proxy: any): number
	local raw = raws[proxy]
	if tracking then
		track(keyNode(raw, ITERATE))
	end
	return #raw
end

function proxyMeta.__iter(proxy: any)
	local raw = raws[proxy]
	if tracking then
		track(keyNode(raw, ITERATE))
	end
	return function(_, key)
		local nextKey, value = next(raw, key)
		return nextKey, wrap(value)
	end
end

function proxyMeta.__tostring(proxy: any): string
	return "Reactive(" .. tostring(raws[proxy]) .. ")"
end

--[[
	A deeply reactive view of `target`. Reads are tracked per key, writes notify only
	the readers of that key. Use generalized iteration (`for k, v in t`) and `#t`;
	the table library works on raw tables, so use Lucy.insert / Lucy.remove for lists.
]]
function Reactive.reactive<T>(target: T): T
	assert(type(target) == "table", "[Lucy] reactive needs a table")
	if raws[target] ~= nil or table.isfrozen(target :: any) then
		return target
	end
	local existing = proxies[target]
	if existing then
		return existing
	end
	local proxy = setmetatable({}, proxyMeta)
	raws[proxy] = target
	proxies[target] = proxy
	return proxy :: any
end

function Reactive.isReactive(value: any): boolean
	return type(value) == "table" and raws[value] ~= nil
end

function Reactive.toRaw<T>(value: T): T
	return if type(value) == "table" then raws[value] or value else value
end

-- table.insert that keeps reactive lists reactive. insert(list, value) or insert(list, pos, value).
function Reactive.insert(list: { any }, ...)
	local raw = raws[list]
	if raw == nil then
		table.insert(list, ...)
		return
	end
	local pos, value
	if select("#", ...) == 1 then
		value = ...
		pos = #raw + 1
	else
		pos, value = ...
	end
	table.insert(raw, pos, unwrap(value))
	changed(raw, nil, true, pos)
end

-- table.remove that keeps reactive lists reactive.
function Reactive.remove(list: { any }, pos: number?): any
	local raw = raws[list]
	if raw == nil then
		return if pos then table.remove(list, pos) else table.remove(list)
	end
	local index = pos or #raw
	if index < 1 or index > #raw then
		return nil
	end
	local value = table.remove(raw, index)
	changed(raw, nil, true, index)
	return wrap(value)
end

-- Store integration (ADR 0017) -------------------------------------------------------
-- Internal: AppState keeps a tree of plain tables and uses the same per-key sources
-- as `reactive`, so the store and the reactive core are one change system.

-- Tracks key `key` of the plain table `raw` in the running computed or effect.
function Reactive._trackKey(raw: any, key: any)
	if tracking then
		track(keyNode(raw, key))
	end
end

-- Notifies readers of `raw[key]`; `structural` when the key appeared or went away.
function Reactive._changedKey(raw: any, key: any, structural: boolean)
	if keyNodes[raw] then
		changed(raw, key, structural, nil)
	end
end

-- Brackets a multi-key mutation: effects run once, at the end.
function Reactive._begin()
	batchDepth += 1
end

function Reactive._finish()
	batchDepth -= 1
	if batchDepth == 0 then
		flush()
	end
end

-- True when something (an effect, a scope) would own effects created now.
function Reactive._hasOwner(): boolean
	return owner ~= nil
end

-- The node (effect or scope) that owns what is created now, or nil.
function Reactive._owner(): any
	return owner
end

-- True inside Lucy.batch.
function Reactive._inBatch(): boolean
	return userBatch > 0
end

--[[
	A ref-like accessor over other sources: calling it reads `get` (tracking what
	get reads), calling it with a value calls `set`. Counts as a writable ref
	(isRef, isWritable) but adds no node of its own to the graph: cheaper than a
	writable computed when get is already a cheap read of tracked sources.
]]
local ACCESSOR = table.freeze({ kind = "accessor", writable = true })

function Reactive._accessor<T>(get: () -> T, set: (value: T) -> ()): Ref<T>
	local function accessor(...: any): any
		if select("#", ...) == 0 then
			return get()
		end
		set((...))
		return nil
	end
	nodeOf[accessor] = ACCESSOR
	return accessor :: any
end

-- Marks `fn` (called with no argument it reads, with one it writes) as an accessor
-- ref, for callers that build the single closure themselves. Returns `fn`.
function Reactive._markAccessor(fn: (...any) -> any): any
	nodeOf[fn] = ACCESSOR
	return fn
end

-- `untrack` for hot paths: one result, no allocation.
function Reactive._untracked(fn: (...any) -> any, ...: any): any
	local previous = tracking
	tracking = nil
	local ok, result = pcall(fn, ...)
	tracking = previous
	if not ok then
		error(result, 0)
	end
	return result
end

-- Runs `hook` once, when the outermost Lucy.batch ends.
function Reactive._afterBatch(hook: () -> ())
	endHookCount += 1
	endHooks[endHookCount] = hook
end

return Reactive
