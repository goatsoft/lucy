--!strict
--[[
	DataQueue: a game's DataStore traffic on the server, paced to the engine's limits
	(ADR 0035). Writes return at once and are sent when the engine has room; reads are
	cached; what is pending is written when the server closes.

		local queue = Lucy.DataQueue.new()
		local profiles = queue:store("Profiles")
		local hype = queue:ordered("Leaderboard_Hype")

		profiles:set("u123", profile)           -- queued; a later set to the key replaces it
		profiles:update("u123", function(old)   -- UpdateAsync; updates to one key compose
			return old
		end)
		profiles:remove("u123")
		local saved = profiles:get("u123")      -- yields: a pending write, else the cache, else
		                                        -- the store ({ fresh = true } skips the cache)
		hype:set("u123", 4200)
		local top = hype:top(10)                -- { { key, value } }, highest first; cached for
		                                        -- ttl, pending writes merged in
		queue:flush(5)                          -- yields until written (true) or the timeout

	How it paces:
		One pending write per key: set replaces it, update composes onto it. A key is
		written no sooner than keyGap seconds after its last write (the engine's per-key
		limit), and only while GetRequestBudgetForRequestType has room for that kind of
		request, so a busy key never holds up the others. A failed write is tried again
		after retryDelay, doubling, up to retries times, then dropped with a warning
		(queue.onError, if set, hears about it).

	Reads:
		get answers from a pending set first (a game reads what it wrote), then from what
		the queue last read or wrote (kept ttl seconds), then from the store. top keeps
		each sorted page ttl seconds; once it has a page it answers at once and, when the
		page is stale, refreshes it in the background.

	Closing:
		The queue binds BindToClose and flushes, waiting at most closeTimeout seconds
		(5 in Studio, 25 live).

	Offline:
		When DataStores cannot be reached (an unpublished place, API access off) the
		handles keep everything in memory, and the queue says so once (queue.offline).

	options (all optional):
		ttl            seconds a read is kept (60)
		keyGap         seconds between writes to one key (6)
		retries        tries for a write (3)
		retryDelay     seconds before the first retry, doubling after (1)
		closeTimeout   seconds BindToClose waits (5 in Studio, 25 live)
		interval       seconds between steps when it runs itself (0.25)
		bindToClose    false to leave BindToClose alone (specs)
		autoRun        false to step only on queue:step() (specs)
		service        a DataStoreService (specs pass a fake)
		clock, wait, spawn, warn   the time, a yield, a thread starter and a warner (specs)
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataQueue = {}
DataQueue.__index = DataQueue

export type Entry = { key: string, value: any }

export type Options = {
	ttl: number?,
	keyGap: number?,
	retries: number?,
	retryDelay: number?,
	closeTimeout: number?,
	interval: number?,
	bindToClose: boolean?,
	autoRun: boolean?,
	service: any?,
	clock: (() -> number)?,
	wait: ((seconds: number?) -> ...any)?,
	spawn: ((fn: (...any) -> ...any, ...any) -> ...any)?,
	warn: ((...any) -> ())?,
}

type Write = {
	kind: "set" | "update" | "remove",
	value: any,
	fns: { (any) -> any }?,
	tries: number,
	notBefore: number,
}

type Cached = { value: any, at: number }

type Page = { list: { Entry }, at: number, refreshing: boolean, loading: boolean }

type Handle = {
	queue: any,
	name: string,
	ordered: boolean,
	store: any,
	writes: { [string]: Write },
	inFlight: { [string]: boolean },
	lastWrite: { [string]: number },
	cache: { [string]: Cached },
	memory: { [string]: any },
	pages: { [string]: Page },
	written: { [string]: Cached },
}

local Handle = {}
Handle.__index = Handle

-- The engine's request kinds, for GetRequestBudgetForRequestType
local function writeKind(handle: any, write: Write): Enum.DataStoreRequestType
	if write.kind == "update" then
		return Enum.DataStoreRequestType.UpdateAsync
	elseif handle.ordered then
		return Enum.DataStoreRequestType.SetIncrementSortedAsync
	end
	return Enum.DataStoreRequestType.SetIncrementAsync
end

function DataQueue.new(options: Options?): any
	local opts: Options = options or {}
	local studio = RunService:IsStudio()
	local self = setmetatable({
		service = opts.service or DataStoreService,
		ttl = opts.ttl or 60,
		keyGap = opts.keyGap or 6,
		retries = opts.retries or 3,
		retryDelay = opts.retryDelay or 1,
		closeTimeout = opts.closeTimeout or (if studio then 5 else 25),
		interval = opts.interval or 0.25,
		clock = opts.clock or os.clock,
		wait = opts.wait or task.wait,
		spawn = opts.spawn or task.spawn,
		warn = (opts.warn or warn) :: (...any) -> (),
		onError = nil :: ((info: { [string]: any }) -> ())?,
		offline = false,
		handles = {} :: { Handle },
		_budget = {} :: { [any]: number },
		_connection = nil :: RBXScriptConnection?,
		destroyed = false,
	}, DataQueue)

	-- Can DataStores be reached at all?
	local ok = pcall(function()
		return self.service:GetDataStore("LucyDataQueueProbe")
	end)
	if not ok then
		self.offline = true
		self.warn("[Lucy] DataQueue: DataStores cannot be reached here; saving in memory for this session")
	end

	if opts.autoRun ~= false then
		local since = 0
		self._connection = RunService.Heartbeat:Connect(function(dt: number)
			since += dt
			if since >= self.interval then
				since = 0
				self:step()
			end
		end)
	end
	if opts.bindToClose ~= false then
		game:BindToClose(function()
			if not self.destroyed and not self:flush(self.closeTimeout) then
				self.warn(
					`[Lucy] DataQueue: {self:pending()} writes were still waiting when the server closed`
				)
			end
		end)
	end
	return self
end

local function makeHandle(queue: any, name: string, scope: string?, ordered: boolean): any
	local store = nil
	if not queue.offline then
		local ok, result = pcall(function()
			if ordered then
				return queue.service:GetOrderedDataStore(name, scope)
			end
			return queue.service:GetDataStore(name, scope)
		end)
		if ok then
			store = result
		else
			queue.warn(`[Lucy] DataQueue: cannot open "{name}": {result}`)
		end
	end
	local handle = setmetatable({
		queue = queue,
		name = name,
		ordered = ordered,
		store = store,
		writes = {},
		inFlight = {},
		lastWrite = {},
		cache = {},
		memory = {},
		pages = {},
		written = {},
	}, Handle)
	table.insert(queue.handles, handle)
	return handle
end

-- A handle on a DataStore
function DataQueue.store(self: any, name: string, scope: string?): any
	return makeHandle(self, name, scope, false)
end

-- A handle on an OrderedDataStore (numbers, with top)
function DataQueue.ordered(self: any, name: string, scope: string?): any
	return makeHandle(self, name, scope, true)
end

-- Room for one more request of `kind` this step
function DataQueue._spend(self: any, kind: Enum.DataStoreRequestType): boolean
	local left = self._budget[kind]
	if left == nil then
		local ok, budget = pcall(function()
			return self.service:GetRequestBudgetForRequestType(kind)
		end)
		left = if ok and type(budget) == "number" then budget else 0
	end
	if left <= 0 then
		self._budget[kind] = 0
		return false
	end
	self._budget[kind] = left - 1
	return true
end

-- Waits until a request of `kind` has room (reads)
function DataQueue._waitFor(self: any, kind: Enum.DataStoreRequestType)
	while not self.destroyed and not self:_spend(kind) do
		self.wait(0.25)
		table.clear(self._budget)
	end
end

-- Sends what is ready: called every interval when the queue runs itself
function DataQueue.step(self: any)
	if self.destroyed then
		return
	end
	table.clear(self._budget)
	local now = self.clock()
	for _, handle in self.handles do
		handle:_send(now)
	end
end

-- How many writes are waiting or on their way
function DataQueue.pending(self: any): number
	local n = 0
	for _, handle in self.handles do
		for _ in handle.writes do
			n += 1
		end
		for key in handle.inFlight do
			if not handle.writes[key] then
				n += 1
			end
		end
	end
	return n
end

-- Writes everything pending, waiting at most `timeout` seconds. True when nothing is left.
function DataQueue.flush(self: any, timeout: number?): boolean
	local limit = timeout or self.closeTimeout
	local start = self.clock()
	self:step()
	while self:pending() > 0 and self.clock() - start < limit do
		self.wait(0.1)
		self:step()
	end
	return self:pending() == 0
end

function DataQueue.destroy(self: any)
	self.destroyed = true
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

-- Handles -------------------------------------------------------------------------------------

local function remember(handle: any, key: string, value: any)
	local now = handle.queue.clock()
	handle.cache[key] = { value = value, at = now }
	handle.memory[key] = value
	if handle.ordered then
		handle.written[key] = { value = value, at = now }
	end
end

local function queueWrite(handle: any, key: string, write: Write)
	if handle.queue.offline or not handle.store then
		-- Offline: what would be written is what there is
		if write.kind == "remove" then
			handle.memory[key] = nil
			handle.cache[key] = nil
			handle.written[key] = nil
		else
			local value = write.value
			if write.kind == "update" and write.fns then
				value = handle.memory[key]
				for _, fn in write.fns do
					value = fn(value)
				end
			end
			remember(handle, key, value)
		end
		return
	end
	handle.writes[key] = write
end

function Handle.set(self: any, key: string, value: any)
	queueWrite(self, key, { kind = "set", value = value, tries = 0, notBefore = 0 })
	if self.ordered and not self.queue.offline then
		self.written[key] = { value = value, at = self.queue.clock() }
	end
end

function Handle.update(self: any, key: string, fn: (any) -> any)
	local pending = self.writes[key]
	if pending and pending.kind == "set" then
		-- On a pending set: the new value is known, no read needed
		pending.value = fn(pending.value)
		if self.ordered then
			self.written[key] = { value = pending.value, at = self.queue.clock() }
		end
		return
	end
	if pending and pending.kind == "update" and pending.fns then
		table.insert(pending.fns, fn)
		return
	end
	queueWrite(self, key, { kind = "update", fns = { fn }, tries = 0, notBefore = 0 })
end

function Handle.remove(self: any, key: string)
	queueWrite(self, key, { kind = "remove", tries = 0, notBefore = 0 })
	self.written[key] = nil
end

-- Sends this handle's ready writes
function Handle._send(self: any, now: number)
	local queue = self.queue
	for key, write in self.writes do
		if self.inFlight[key] or now < write.notBefore then
			continue
		end
		local last = self.lastWrite[key]
		if last and now - last < queue.keyGap then
			continue
		end
		if not queue:_spend(writeKind(self, write)) then
			continue
		end
		self.writes[key] = nil
		self.inFlight[key] = true
		write.tries += 1
		queue.spawn(function()
			local ok, result = pcall(function(): any
				if write.kind == "set" then
					self.store:SetAsync(key, write.value)
					return write.value
				elseif write.kind == "remove" then
					self.store:RemoveAsync(key)
					return nil
				end
				local fns = write.fns or {}
				return self.store:UpdateAsync(key, function(old)
					local value = old
					for _, fn in fns do
						value = fn(value)
					end
					return value
				end)
			end)
			self.inFlight[key] = nil
			local at = queue.clock()
			if ok then
				self.lastWrite[key] = at
				if write.kind == "remove" then
					self.cache[key] = nil
					self.memory[key] = nil
				else
					remember(self, key, result)
				end
				return
			end
			if self.writes[key] then
				return -- a newer write to the key is waiting; it replaces this one
			end
			if write.tries >= queue.retries then
				queue.warn(`[Lucy] DataQueue: gave up writing "{key}" to "{self.name}": {result}`)
				if queue.onError then
					queue.onError({ store = self.name, key = key, error = result })
				end
				return
			end
			write.notBefore = at + queue.retryDelay * 2 ^ (write.tries - 1)
			self.writes[key] = write
		end)
	end
end

-- The value at `key` (yields). options.fresh skips the cache.
function Handle.get(self: any, key: string, options: { fresh: boolean? }?): any
	local queue = self.queue
	local pending = self.writes[key]
	if pending and pending.kind == "set" then
		return pending.value
	end
	if pending and pending.kind == "remove" then
		return nil
	end
	local value
	local cached = self.cache[key]
	if queue.offline or not self.store then
		value = self.memory[key]
	elseif cached and not (options and options.fresh) and queue.clock() - cached.at < queue.ttl then
		value = cached.value
	else
		queue:_waitFor(Enum.DataStoreRequestType.GetAsync)
		local ok, result = pcall(function()
			return self.store:GetAsync(key)
		end)
		if not ok then
			error(`[Lucy] DataQueue: could not read "{key}" from "{self.name}": {result}`, 0)
		end
		value = result
		self.cache[key] = { value = value, at = queue.clock() }
		self.memory[key] = value
	end
	-- A pending update has not landed: show what it will make
	if pending and pending.kind == "update" and pending.fns then
		for _, fn in pending.fns do
			value = fn(value)
		end
	end
	return value
end

-- The page, with what this server wrote since it was read
local function merged(self: any, page: Page?, count: number, ascending: boolean): { Entry }
	local byKey: { [string]: any } = {}
	local fetchedAt = if page then page.at else -math.huge
	if page then
		for _, entry in page.list do
			byKey[entry.key] = entry.value
		end
	end
	for key, entry in self.written do
		if entry.at >= fetchedAt then
			byKey[key] = entry.value
		end
	end
	local list: { Entry } = {}
	for key, value in byKey do
		if type(value) == "number" then
			table.insert(list, { key = key, value = value })
		end
	end
	table.sort(list, function(a, b)
		if a.value == b.value then
			return a.key < b.key
		end
		if ascending then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	local out = {}
	for i = 1, math.min(count, #list) do
		out[i] = list[i]
	end
	return out
end

local function fetchPage(self: any, page: Page, count: number, ascending: boolean)
	local queue = self.queue
	queue:_waitFor(Enum.DataStoreRequestType.GetSortedAsync)
	local started = queue.clock()
	local ok, result = pcall(function()
		local pages = self.store:GetSortedAsync(ascending, count)
		return pages:GetCurrentPage()
	end)
	if ok and type(result) == "table" then
		local list = {}
		for _, item in result do
			table.insert(list, { key = tostring(item.key), value = item.value })
		end
		page.list = list
		page.at = started
		-- What the store now has supersedes what this server wrote before the read
		for key, entry in self.written do
			if entry.at < started and not self.writes[key] and not self.inFlight[key] then
				self.written[key] = nil
			end
		end
	else
		queue.warn(`[Lucy] DataQueue: could not read the top of "{self.name}": {result}`)
		page.at = queue.clock() -- try again after ttl, not every call
	end
end

-- The top `count` entries of an ordered store, highest first (options.ascending: lowest first).
-- Yields only the first time; after that it answers at once and refreshes when stale.
function Handle.top(self: any, count: number, options: { ascending: boolean?, ttl: number? }?): { Entry }
	assert(self.ordered, "[Lucy] DataQueue: top needs an ordered store (queue:ordered)")
	local queue = self.queue
	local ascending = options and options.ascending == true or false
	local ttl = (options and options.ttl) or queue.ttl
	if queue.offline or not self.store then
		local list = {}
		for key, value in self.memory do
			if type(value) == "number" then
				table.insert(list, { key = key, value = value })
			end
		end
		table.sort(list, function(a, b)
			if ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		local out = {}
		for i = 1, math.min(count, #list) do
			out[i] = list[i]
		end
		return out
	end

	local id = `{count}:{ascending}`
	local page = self.pages[id]
	if not page then
		page = { list = {}, at = -math.huge, refreshing = false, loading = true }
		self.pages[id] = page
		fetchPage(self, page, count, ascending)
		page.loading = false
		return merged(self, page, count, ascending)
	end
	while page.loading do
		queue.wait(0.1)
	end
	local answer = merged(self, page, count, ascending)
	if queue.clock() - page.at >= ttl and not page.refreshing then
		page.refreshing = true
		queue.spawn(function()
			fetchPage(self, page :: Page, count, ascending);
			(page :: Page).refreshing = false
		end)
	end
	return answer
end

return DataQueue
