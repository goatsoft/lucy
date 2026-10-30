--[[
	AppState: a small, synchronous, path-addressed store.

	State is a plain tree of tables. Writes are copy-on-write: every table on the
	path to a change is cloned, so a value you read earlier never changes under
	you, and "did this path change" is a cheap identity check.

	Paths are dot strings ("ui.playButton.disabled"). Subscribers are told when the
	value at their path changes, which includes changes to ancestors and descendants.

		local state = AppState.new({ ui = {} })
		local stop = state:subscribe("ui.play.disabled", function(new, old) end)
		state:set("ui.play.disabled", true)
		state:merge("ui.play", { text = "Go" })
		state:batch(function() ... end) -- one notification per subscriber
		stop()

		local coins = state:ref("player.coins") -- a writable ref onto a path (ADR 0014)
		coins(coins() + 10)                     -- same as state:set("player.coins", ...)

	Components keep their props under "ui.<id>", the SceneManager under "scenes",
	toasts under "toasts" and the theme name under "theme". See docs/architecture.md.
]]

local Reactive = require(script.Parent.Reactive)

local AppState = {}
AppState.__index = AppState

local function split(path: string?): { string }
	if path == nil or path == "" then
		return {}
	end
	local segments = string.split(path :: string, ".")
	for _, segment in segments do
		if segment == "" then
			error(`[Lucy] invalid state path "{path}"`, 3)
		end
	end
	return segments
end

local function read(root: any, segments: { string }): any
	local node = root
	for _, key in segments do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

-- Returns a new root with `value` written at `segments`, cloning every table on the way.
local function write(root: any, segments: { string }, index: number, value: any): any
	if index > #segments then
		return value
	end
	local node = if type(root) == "table" then table.clone(root) else {}
	local key = segments[index]
	node[key] = write(node[key], segments, index + 1, value)
	return node
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

function AppState.new(initial: { [string]: any }?)
	local self = setmetatable({}, AppState)
	self._root = if initial then table.clone(initial) else {}
	self._subscribers = {}
	self._batchDepth = 0
	self._batchRoot = nil
	return self
end

function AppState:get(path: string?): any
	return read(self._root, split(path))
end

function AppState:_notify(oldRoot: any, newRoot: any)
	for _, sub in table.clone(self._subscribers) do
		if sub.alive then
			local old = read(oldRoot, sub.segments)
			local new = read(newRoot, sub.segments)
			if old ~= new then
				local ok, err = pcall(sub.fn, new, old)
				if not ok then
					warn(`[Lucy] state subscriber for "{sub.path}" errored: {err}`)
				end
			end
		end
	end
end

function AppState:_commit(newRoot: any)
	local oldRoot = self._root
	if oldRoot == newRoot then
		return
	end
	self._root = newRoot
	if self._batchDepth == 0 then
		self:_notify(oldRoot, newRoot)
	end
end

function AppState:set(path: string?, value: any)
	local segments = split(path)
	if read(self._root, segments) == value then
		return
	end
	self:_commit(write(self._root, segments, 1, value))
end

function AppState:update(path: string?, fn: (any) -> any)
	self:set(path, fn(self:get(path)))
end

-- Shallow-merges `patch` into the table at `path`; only writes when something differs.
function AppState:merge(path: string?, patch: { [string]: any })
	local current = self:get(path)
	local base = if type(current) == "table" then current else {}
	local changed = type(current) ~= "table"
	for key, value in patch do
		if base[key] ~= value then
			changed = true
			break
		end
	end
	if not changed then
		return
	end
	local merged = table.clone(base)
	for key, value in patch do
		merged[key] = value
	end
	self:set(path, merged)
end

function AppState:remove(path: string)
	self:set(path, nil)
end

function AppState:subscribe(path: string?, fn: (new: any, old: any) -> ()): () -> ()
	local sub = { path = path or "", segments = split(path), fn = fn, alive = true }
	table.insert(self._subscribers, sub)
	return function()
		if not sub.alive then
			return
		end
		sub.alive = false
		local index = table.find(self._subscribers, sub)
		if index then
			table.remove(self._subscribers, index)
		end
	end
end

--[[
	A writable ref onto `path`: reading tracks the value at the path, writing sets it.
	The subscription ends with the current effect / scope (or lives with the store).
]]
function AppState:ref(path: string?): Reactive.Ref<any>
	local value = Reactive.ref(self:get(path))
	local stop = self:subscribe(path, function(new)
		value(new)
	end)
	Reactive.onCleanup(stop)
	return Reactive.computed({
		get = function()
			return value()
		end,
		set = function(new: any)
			self:set(path, new)
		end,
	}) :: any
end

-- Runs `fn` and delivers at most one notification per subscriber afterwards.
function AppState:batch(fn: () -> ())
	if self._batchDepth == 0 then
		self._batchRoot = self._root
	end
	self._batchDepth += 1
	local ok, err = pcall(fn)
	self._batchDepth -= 1
	if self._batchDepth == 0 then
		local before = self._batchRoot
		self._batchRoot = nil
		self:_notify(before, self._root)
	end
	if not ok then
		error(err, 2)
	end
end

-- A view of the store with every path prefixed, so a component can own "ui.<id>".
function AppState:scope(prefix: string)
	local store = self
	local scoped = {}
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
	return scoped
end

function AppState:destroy()
	for _, sub in self._subscribers do
		sub.alive = false
	end
	self._subscribers = {}
end

return AppState
