--!strict
--[[
	Boards: a game's leaderboards on the server, kept in OrderedDataStores through the
	game's Lucy.DataQueue (ADR 0043). All time, this week and today, each dancer's own rank,
	their names, and the request and published rows a client's Leaderboard reads.

		local boards = Lucy.Boards.new({
			queue = data,                     -- the game's one Lucy.DataQueue
			server = server,                  -- answers "boards.get", and publish writes here
			boards = {
				combo = { store = "BestCombos", periods = { "all", "week" } },  -- keeps the best
				coins = { store = "CoinsEarned", kind = "total" },              -- adds up
			},
		})

		boards:post(player, "combo", 42)      -- best: kept if higher; total: added. Every period
		boards:set(player, "combo", 42, "week") -- this value as it is, in one period (or all)
		boards:get("combo", "week", player)   -- { board, period, rows, me } (yields the first time)
		boards:top("combo", "all", 5)         -- just the rows
		boards:publish("combo", { count = 5 })  -- top rows at shared.boards.combo, every 60 s
		boards:refresh()                      -- publish everything again now

	A row is { userId, name, value, rank }. `me` is the asking player's own row: ranked
	when they are in the top `depth` (an OrderedDataStore cannot give one key's rank), else
	their value with no rank, so the client can show "100+".

	Periods:
		all    the store itself
		week   the store in scope w<week>; weeks start Monday 00:00 UTC
		day    the store in scope d<day>; days start 00:00 UTC
	A new week or day starts empty, with no reset to run. Keys are user ids as strings.

	options:
		queue     the game's Lucy.DataQueue (required)
		boards    { [id] = { store, kind?, periods? } }: kind "best" (default) or "total";
		          periods default { "all", "week" }
		server    a Lucy.Server: answers `request` and holds what publish writes
		request   the request's name ("boards.get"), false for none
		top       rows a get returns (20)
		depth     how far down the asking player's rank is looked up (100)
		name      fn(userId) -> string?: the game's own names, asked first (bots, specs)
		now       fn() -> unix seconds (os.time), for specs
]]

local Players = game:GetService("Players")

local Boards = {}
Boards.__index = Boards

export type Row = { userId: number, name: string, value: number, rank: number? }
export type Answer = { board: string, period: string, rows: { Row }, me: Row? }

Boards.kinds = { "best", "total" }
Boards.periods = { "all", "week", "day" }

local DAY = 24 * 60 * 60
local WEEK = 7 * DAY
-- 1970-01-01 was a Thursday: weeks count from the Monday before it
local MONDAY_OFFSET = 3 * DAY

-- The week a time falls in, counting from Monday 1969-12-29 (weeks start Monday 00:00 UTC)
function Boards.weekId(t: number): number
	return math.floor((t + MONDAY_OFFSET) / WEEK)
end

-- The day a time falls in (days start 00:00 UTC)
function Boards.dayId(t: number): number
	return math.floor(t / DAY)
end

-- The store scope of a period at a time: nil for all time
function Boards.scopeOf(period: string, t: number): string?
	if period == "week" then
		return `w{Boards.weekId(t)}`
	elseif period == "day" then
		return `d{Boards.dayId(t)}`
	end
	return nil
end

local function userIdOf(who: any): number
	if type(who) == "number" then
		return who
	end
	return who.UserId
end

function Boards.new(options: { [string]: any }): any
	assert(options and options.queue, "[Lucy] Boards: needs the game's DataQueue (queue)")
	local defs = {}
	for id, def in options.boards or {} do
		assert(type(def.store) == "string", `[Lucy] Boards: board "{id}" needs a store name`)
		local kind = def.kind or "best"
		if not table.find(Boards.kinds, kind) then
			error(`[Lucy] Boards: board "{id}" has an unknown kind "{kind}" (best or total)`, 2)
		end
		local periods = def.periods or { "all", "week" }
		for _, period in periods do
			if not table.find(Boards.periods, period) then
				error(`[Lucy] Boards: board "{id}" has an unknown period "{period}" (all, week or day)`, 2)
			end
		end
		defs[id] = { store = def.store, kind = kind, periods = periods }
	end

	local self = setmetatable({
		queue = options.queue,
		server = options.server,
		defs = defs,
		top_ = options.top or 20,
		depth = options.depth or 100,
		nameFn = options.name,
		now = options.now or os.time,
		names = {} :: { [number]: string },
		handles = {} :: { [string]: any },
		publishes = {} :: { { id: string, period: string, count: number, path: string } },
		threads = {} :: { thread },
		stopRequest = nil :: (() -> ())?,
		destroyed = false,
	}, Boards)

	local request = if options.request == nil then "boards.get" else options.request
	if self.server and request then
		self.stopRequest = self.server:handle(request, function(player: any, id: any, period: any)
			return self:get(id, period, player)
		end)
	end
	return self
end

-- The board's definition, or an error naming what was asked for (a client can send anything)
function Boards._def(self: any, id: any, period: any): (any, string)
	local def = type(id) == "string" and self.defs[id]
	if not def then
		error(`[Lucy] Boards: no board "{tostring(id)}"`, 3)
	end
	local p = if period == nil then def.periods[1] else period
	if not table.find(def.periods, p) then
		error(`[Lucy] Boards: board "{id}" has no period "{tostring(period)}"`, 3)
	end
	return def, p
end

-- The DataQueue handle for a board's period as it is now (a new week opens a new scope)
function Boards._handle(self: any, id: string, period: string): any
	local def = self.defs[id]
	local scope = Boards.scopeOf(period, self.now())
	local key = `{id}/{scope or "all"}`
	local handle = self.handles[key]
	if not handle then
		handle = if scope then self.queue:ordered(def.store, scope) else self.queue:ordered(def.store)
		self.handles[key] = handle
	end
	return handle
end

function Boards._remember(self: any, who: any)
	if type(who) ~= "number" and who.DisplayName then
		self.names[who.UserId] = who.DisplayName
	end
end

function Boards._nameOf(self: any, userId: number): string
	local own = self.nameFn and self.nameFn(userId)
	if own then
		return own
	end
	local known = self.names[userId]
	if known then
		return known
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self.names[userId] = player.DisplayName
		return player.DisplayName
	end
	if userId > 0 then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if ok and type(name) == "string" and name ~= "" then
			self.names[userId] = name
			return name
		end
	end
	return "Someone"
end

-- Adds `value` to a dancer's boards: the higher of the two on a best board, the sum on a
-- total board, in every period the board keeps.
function Boards.post(self: any, who: any, id: string, value: number)
	local def = self:_def(id, nil)
	local amount = math.floor(value)
	if amount <= 0 then
		return
	end
	self:_remember(who)
	local key = tostring(userIdOf(who))
	for _, period in def.periods do
		local handle = self:_handle(id, period)
		if def.kind == "total" then
			handle:update(key, function(had)
				return (tonumber(had) or 0) + amount
			end)
		else
			handle:update(key, function(had)
				return math.max(tonumber(had) or 0, amount)
			end)
		end
	end
end

-- Writes a dancer's value as it is: in one period, or every period the board keeps. For a
-- game that already keeps the numbers (a profile with this week's stats).
function Boards.set(self: any, who: any, id: string, value: number, period: string?)
	local def = self:_def(id, period)
	local amount = math.floor(value)
	if amount <= 0 then
		return
	end
	self:_remember(who)
	local key = tostring(userIdOf(who))
	for _, p in if period then { period } else def.periods do
		self:_handle(id, p):set(key, amount)
	end
end

-- The board's top `depth`, as { userId, value } best first. Every read asks for the same page,
-- so the queue keeps one cached page per board and period.
function Boards._page(self: any, id: string, period: string): { { userId: number, value: number } }
	local list = {}
	for _, entry in self:_handle(id, period):top(self.depth) do
		local userId = tonumber(entry.key)
		local value = tonumber(entry.value)
		if userId and value and value > 0 then
			table.insert(list, { userId = userId, value = value })
		end
	end
	return list
end

function Boards._rows(self: any, page: { { userId: number, value: number } }, count: number): { Row }
	local rows = {}
	for rank = 1, math.min(count, #page) do
		local entry = page[rank]
		rows[rank] =
			{ userId = entry.userId, name = self:_nameOf(entry.userId), value = entry.value, rank = rank }
	end
	return rows
end

-- The top `count` rows of a board's period (yields the first time a page is read)
function Boards.top(self: any, id: string, period: string?, count: number?): { Row }
	local _, p = self:_def(id, period)
	return self:_rows(self:_page(id, p), count or self.top_)
end

-- The board's top rows and, with a player, their own row
function Boards.get(self: any, id: any, period: any, who: any?): Answer
	if self.destroyed then
		error("[Lucy] Boards: destroyed", 2)
	end
	local _, p = self:_def(id, period)
	local page = self:_page(id, p)
	local answer: Answer = { board = id, period = p, rows = self:_rows(page, self.top_), me = nil }
	if who ~= nil then
		self:_remember(who)
		local userId = userIdOf(who)
		local me: Row = { userId = userId, name = self:_nameOf(userId), value = 0, rank = nil }
		for rank, entry in page do
			if entry.userId == userId then
				me.rank, me.value = rank, entry.value
				break
			end
		end
		if not me.rank then
			local ok, value = pcall(function()
				return self:_handle(id, p):get(tostring(userId))
			end)
			me.value = if ok then math.max(0, tonumber(value) or 0) else 0
		end
		answer.me = me
	end
	return answer
end

function Boards._publishOne(self: any, item: { id: string, period: string, count: number, path: string })
	local ok, rows = pcall(self.top, self, item.id, item.period, item.count)
	if ok and self.server and not self.destroyed then
		self.server.state:set(item.path, rows)
	end
end

-- Keeps a board's top rows in the server's state for every player (a wall, a HUD), read
-- now and again every `every` seconds. options: period ("all"), count (top), path
-- ("shared.boards.<id>", or ".<id>.<period>" for another period), every (60).
function Boards.publish(self: any, id: string, options: { [string]: any }?)
	assert(self.server, "[Lucy] Boards: publish needs the server (options.server)")
	local opts = options or {}
	local _, period = self:_def(id, opts.period or "all")
	local item = {
		id = id,
		period = period,
		count = opts.count or self.top_,
		path = opts.path or (if period == "all" then `shared.boards.{id}` else `shared.boards.{id}.{period}`),
	}
	table.insert(self.publishes, item)
	self:_publishOne(item)
	local every = opts.every or 60
	table.insert(
		self.threads,
		task.spawn(function()
			while not self.destroyed do
				task.wait(every)
				self:_publishOne(item)
			end
		end)
	)
end

-- Publishes every published board again now (after a round, say), yielding while it reads
function Boards.refresh(self: any)
	for _, item in self.publishes do
		self:_publishOne(item)
	end
end

function Boards.destroy(self: any)
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.stopRequest then
		self.stopRequest()
	end
	for _, thread in self.threads do
		pcall(task.cancel, thread)
	end
	table.clear(self.threads)
end

return Boards
