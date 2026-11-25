--!strict
--[[
	Server: the server half of Lucy (ADR 0033, ADR 0058). The same store as the App's, on
	the server, sending what players may see to their Apps and taking their requests.

		local server = Lucy.Server.new({ state = { shared = { show = { phase = "Signup" } } } })

		server.state:set("shared.show.phase", "Live")      -- every player sees server.show.phase
		server:player(player):set("coins", 50)             -- this player sees server.me.coins
		server.state:set("rounds.seed", 1234)              -- stays on the server

		server:handle("signup", function(player, genre)    -- app.server:send / call("signup", ...)
			...                                             -- genre is already a short string
		end, { check = { Lucy.Check.string({ max = 24 }) }, rate = { perSecond = 2 } })

		server:handle("aim", function(player, at) ... end, -- app.server:stream("aim", at)
			{ check = { Lucy.Check.vector() }, unreliable = true, rate = { perSecond = 30 } })
		server:stream(nil, "shot", from, to)               -- every ready player, unreliable
		server:stream(player, "hitmarker")                 -- one player

	What replicates:
		shared.*            to every player, at server.* in their App
		players.u<UserId>.* to that player only, at server.me.* in their App
		anything else       nowhere

	Syncing: every flush (each frame, or each flushRate seconds) the server compares what
	changed with what it last sent and sends only the differences. shared is compared once
	for everyone; a player's own state is compared only when it changed. The store's copies
	share every table that did not change, so unchanged parts of the tree cost one
	comparison. A player gets everything when their App says it is ready.

	Requests: every request passes, in order, the player check (in the game), its name (a
	known handler on the right channel), its rate (a token bucket per player per request)
	and its argument checks, and only then reaches the handler. A request that fails any of
	them is dropped, and onReject hears about it (player, name, why), for logging or a kick.

	Two channels:
		reliable    app.server:send / call; arrives once and in order. State, purchases,
		            anything that matters.
		unreliable  app.server:stream / server:stream (an UnreliableRemoteEvent); may be
		            dropped or reordered and each message must stay under about 900 bytes.
		            Aim, effects, positions: anything the next message replaces.
		A handler takes requests on one channel only: `unreliable = true` for the second.

	Wire format (one message per player per flush):
		{ shared = ops?, me = ops? }, each op { path, value } to set or { path } to remove;
		path "" is the whole root. Keys must not contain dots.

	options:
		state       the starting tree (shared and players are added if missing)
		namePrefix  the remotes folder is "<namePrefix>Server" ("Lucy_")
		parent      where the remotes folder goes (ReplicatedStorage)
		rate        the rate for handlers that give none ({ perSecond = 30, burst = 30 })
		strict      true: handle() raises unless it is given a check (an empty list for
		            no arguments), so no request reaches a handler unchecked
		flushRate   seconds between flushes (0, every frame)
		onReject    fn(player, name, why) when a request is dropped
		players     false to skip the Players service (specs); joins come from _join
		transport   { send(player, message), stream(player?, name, ...)? } instead of
		            remotes (specs)
		autoFlush   false to flush only when :flush() is called (specs)
		clock       the time for rate limits (os.clock; specs)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AppState = require(script.Parent.AppState)
local Check = require(script.Parent.Check)
local Maid = require(script.Parent.Maid)

local Server = {}
Server.__index = Server

export type Op = { any }
export type Message = { shared: { Op }?, me: { Op }? }
export type Rate = { perSecond: number, burst: number? }
export type HandleOptions = {
	check: { Check.Check }?,
	rate: Rate?,
	unreliable: boolean?,
}

type Handler = {
	fn: (...any) -> ...any,
	check: ((...any) -> (boolean, string?))?,
	rate: Rate,
	unreliable: boolean,
}

type Bucket = { tokens: number, at: number }

type PlayerEntry = {
	path: string,
	ready: boolean,
	dirty: boolean,
	lastShared: any,
	lastMe: any,
	buckets: { [string]: Bucket },
	stop: () -> (),
}

type Transport = {
	send: (player: any, message: Message) -> (),
	stream: ((player: any?, name: string, ...any) -> ())?,
}

export type Server = typeof(setmetatable(
	{} :: {
		state: AppState.AppState,
		namePrefix: string,
		maid: Maid.Maid,
		strict: boolean,
		rate: Rate,
		flushRate: number,
		onReject: ((player: any, name: string, why: string) -> ())?,
		_clock: () -> number,
		_players: { [any]: PlayerEntry },
		_handlers: { [string]: Handler },
		_sharedDirty: boolean,
		_lastShared: any,
		_transport: Transport,
		destroyed: boolean?,
	},
	Server
))

local DEFAULT_RATE: Rate = { perSecond = 30, burst = 30 }
local MAX_NAME = 64
-- How often a ready player may ask for everything again: one repeat at once (an App that said
-- ready while it was still being made says it again), then one every ten seconds
local READY_RATE: Rate = { perSecond = 0.1, burst = 2 }

local function join(path: string, key: any): string
	local text = tostring(key)
	if string.find(text, ".", 1, true) then
		error(`[Lucy] server state key "{text}" has a dot in it, which a path cannot carry`, 0)
	end
	return if path == "" then text else path .. "." .. text
end

-- The ops that turn `old` into `new`. Tables the store did not change are the same
-- table in both copies, so whole unchanged branches are skipped.
local function diff(old: any, new: any, path: string, out: { Op })
	if rawequal(old, new) then
		return
	end
	if
		type(old) == "table"
		and type(new) == "table"
		and getmetatable(old) == nil
		and getmetatable(new) == nil
	then
		for key, value in new do
			diff(old[key], value, join(path, key), out)
		end
		for key in old do
			if new[key] == nil then
				table.insert(out, { join(path, key) })
			end
		end
	elseif new == nil then
		table.insert(out, { path })
	else
		table.insert(out, { path, new })
	end
end
Server._diff = diff

-- The key a player's state lives under: never all digits, so never an array index.
function Server.playerKey(player: any): string
	return "u" .. tostring(player.UserId)
end

local function remotes(self: Server, parent: Instance): Transport
	local folder = Instance.new("Folder")
	folder.Name = self.namePrefix .. "Server"
	local sync = Instance.new("RemoteEvent")
	sync.Name = "Sync"
	sync.Parent = folder
	local call = Instance.new("RemoteFunction")
	call.Name = "Call"
	call.Parent = folder
	local stream = Instance.new("UnreliableRemoteEvent")
	stream.Name = "Stream"
	stream.Parent = folder

	self.maid:give(sync.OnServerEvent:Connect(function(player: Player, kind: any, ...)
		if kind == "ready" then
			self:_ready(player)
		elseif kind == "send" then
			self:_request(player, ...)
		end
	end))
	call.OnServerInvoke = function(player: Player, name: any, ...)
		return self:_request(player, name, ...)
	end
	self.maid:give(stream.OnServerEvent:Connect(function(player: Player, name: any, ...)
		self:_requestStream(player, name, ...)
	end))
	folder.Parent = parent
	self.maid:give(folder)

	return {
		send = function(player: any, message: Message)
			sync:FireClient(player, message)
		end,
		stream = function(player: any?, name: string, ...)
			if player then
				stream:FireClient(player, name, ...)
			else
				for who, entry in self._players do
					if entry.ready then
						stream:FireClient(who, name, ...)
					end
				end
			end
		end,
	}
end

function Server.new(options: { [string]: any }?): Server
	local opts: { [string]: any } = options or {}
	local self: Server = setmetatable({} :: any, Server)
	self.namePrefix = opts.namePrefix or "Lucy_"
	self.maid = Maid.new()
	self.strict = opts.strict == true
	self.rate = opts.rate or DEFAULT_RATE
	self.flushRate = opts.flushRate or 0
	self.onReject = opts.onReject
	self._clock = opts.clock or os.clock
	self._players = {}
	self._handlers = {}
	self._sharedDirty = false
	self._lastShared = nil

	local initial: { [string]: any } = table.clone(opts.state or {})
	initial.shared = initial.shared or {}
	initial.players = initial.players or {}
	self.state = AppState.new(initial)
	self.maid:give(self.state)
	self._lastShared = self.state:get("shared")

	self._transport = opts.transport or remotes(self, opts.parent or ReplicatedStorage)

	self.maid:give(self.state:subscribe("shared", function()
		self._sharedDirty = true
	end))

	if opts.autoFlush ~= false then
		local since = 0
		self.maid:give(RunService.Heartbeat:Connect(function(dt: number)
			since += dt
			if since >= self.flushRate then
				since = 0
				self:flush()
			end
		end))
	end

	if opts.players ~= false then
		local service: any = opts.players or Players
		self.maid:give(service.PlayerAdded:Connect(function(player)
			self:_join(player)
		end))
		self.maid:give(service.PlayerRemoving:Connect(function(player)
			self:_leave(player)
		end))
		for _, player in service:GetPlayers() do
			self:_join(player)
		end
	end
	return self
end

-- This player's part of the store (players.u<UserId>), seen by them at server.me.*.
function Server.player(self: Server, player: any): any
	return self.state:scope("players." .. Server.playerKey(player))
end

-- Handles requests named `name` from clients: fn(player, ...) and its return value goes
-- back to app.server:call. options.check lists a check per argument (Lucy.Check), and the
-- handler only runs when they all pass; options.rate limits how often one player may ask;
-- options.unreliable takes the request on the unreliable channel (app.server:stream).
function Server.handle(
	self: Server,
	name: string,
	fn: (player: any, ...any) -> ...any,
	options: HandleOptions?
): () -> ()
	if self._handlers[name] then
		error(`[Lucy] the server already handles "{name}"`, 2)
	end
	if #name > MAX_NAME then
		error(`[Lucy] a request name is at most {MAX_NAME} bytes`, 2)
	end
	local opts: HandleOptions = options or {}
	if self.strict and opts.check == nil then
		error(`[Lucy] "{name}" has no check: a strict server checks every request (\{\} for none)`, 2)
	end
	local handler: Handler = {
		fn = fn,
		check = if opts.check then Check.args(opts.check) else nil,
		rate = opts.rate or self.rate,
		unreliable = opts.unreliable == true,
	}
	self._handlers[name] = handler
	return function()
		if self._handlers[name] == handler then
			self._handlers[name] = nil
		end
	end
end

-- Sends `name` and its arguments on the unreliable channel to one player, or to every
-- ready player when player is nil. The App hears it with app.server:onStream(name, fn).
function Server.stream(self: Server, player: any?, name: string, ...)
	local send = self._transport.stream
	if not send then
		return
	end
	if player then
		local entry = self._players[player]
		if not entry or not entry.ready then
			return
		end
	end
	send(player, name, ...)
end

-- Sends each ready player what changed since the last flush.
function Server.flush(self: Server)
	local sharedDirty = self._sharedDirty
	self._sharedDirty = false
	local shared = if sharedDirty then self.state:get("shared") else nil
	-- shared is the same for everyone: compare it once, against what was last sent
	local common: { Op }? = nil
	local previous = self._lastShared
	if sharedDirty then
		common = {}
		diff(previous, shared, "", common :: { Op })
		self._lastShared = shared
	end
	for player, entry in self._players do
		if not entry.ready or not (sharedDirty or entry.dirty) then
			continue
		end
		local message: Message = {}
		if sharedDirty then
			local ops: { Op }
			if rawequal(entry.lastShared, previous) then
				ops = common :: { Op }
			else
				-- Ready since the last flush: what this player has is not what everyone has
				ops = {}
				diff(entry.lastShared, shared, "", ops)
			end
			entry.lastShared = shared
			if #ops > 0 then
				message.shared = ops
			end
		end
		if entry.dirty then
			entry.dirty = false
			local me = self.state:get(entry.path)
			local ops = {}
			diff(entry.lastMe, me, "", ops)
			entry.lastMe = me
			if #ops > 0 then
				message.me = ops
			end
		end
		if message.shared or message.me then
			self._transport.send(player, message)
		end
	end
end

function Server._join(self: Server, player: any)
	if self._players[player] then
		return
	end
	local path = "players." .. Server.playerKey(player)
	if self.state:get(path) == nil then
		self.state:set(path, {})
	end
	local entry: PlayerEntry = {
		path = path,
		ready = false,
		dirty = false,
		lastShared = nil,
		lastMe = nil,
		buckets = {},
		stop = function() end,
	}
	entry.stop = self.state:subscribe(path, function()
		entry.dirty = true
	end)
	self._players[player] = entry
end

function Server._leave(self: Server, player: any)
	local entry = self._players[player]
	if not entry then
		return
	end
	entry.stop()
	self._players[player] = nil
	self.state:remove(entry.path)
end

-- The player's App is listening: send everything they may see.
function Server._ready(self: Server, player: any)
	if not self._players[player] then
		-- A late "ready" from a player who has left must not bring them back
		if typeof(player) == "Instance" and not player.Parent then
			return
		end
		self:_join(player)
	end
	local entry = self._players[player]
	-- Everything again only now and then: a client sending "ready" in a loop would otherwise
	-- make the server send the whole state each time (an App made again gets it after a pause)
	-- (the first ready takes the token too, so a repeat waits a full interval)
	if not self:_take(entry, "lucy:ready", READY_RATE) and entry.ready then
		local onReject = self.onReject
		if onReject then
			task.spawn(onReject, player, "ready", "too many requests")
		end
		return
	end
	entry.ready = true
	entry.dirty = false
	entry.lastShared = self.state:get("shared")
	entry.lastMe = self.state:get(entry.path)
	self._transport.send(player, {
		shared = { { "", entry.lastShared or {} } },
		me = { { "", entry.lastMe or {} } },
	})
end

-- One token from the player's bucket for `name`: false when they ask too often.
function Server._take(self: Server, entry: PlayerEntry, name: string, rate: Rate): boolean
	local now = self._clock()
	-- at least one: a rate under one a second still lets a request through now and then
	local burst = math.max(1, rate.burst or rate.perSecond)
	local bucket = entry.buckets[name]
	if not bucket then
		bucket = { tokens = burst, at = now }
		entry.buckets[name] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.at) * rate.perSecond)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function Server._reject(self: Server, player: any, name: any, why: string): (boolean, string)
	local onReject = self.onReject
	if onReject then
		task.spawn(onReject, player, tostring(name), why)
	end
	return false, why
end

-- A request from a player: (true, results...) from its handler, or (false, reason).
function Server._request(self: Server, player: any, name: any, ...): (boolean, any)
	return self:_receive(player, false, name, ...)
end

-- The same, from the unreliable channel
function Server._requestStream(self: Server, player: any, name: any, ...): (boolean, any)
	return self:_receive(player, true, name, ...)
end

function Server._receive(self: Server, player: any, unreliable: boolean, name: any, ...): (boolean, any)
	local entry = self._players[player]
	if not entry then
		return false, "not in the game"
	end
	if type(name) ~= "string" or #name > MAX_NAME then
		return self:_reject(player, "?", "a request needs a name")
	end
	local handler = self._handlers[name]
	if not handler or handler.unreliable ~= unreliable then
		return self:_reject(player, name, `no handler for "{name}"`)
	end
	if not self:_take(entry, name, handler.rate) then
		return self:_reject(player, name, "too many requests")
	end
	if handler.check then
		local ok, why = handler.check(...)
		if not ok then
			return self:_reject(player, name, `bad request: {why}`)
		end
	end
	local results = table.pack(pcall(handler.fn, player, ...))
	if not results[1] then
		warn(`[Lucy] server handler "{name}" failed: {results[2]}`)
		return false, "the server could not do that"
	end
	return true, results[2]
end

function Server.destroy(self: Server)
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, entry in self._players do
		entry.stop()
	end
	self._players = {}
	self._handlers = {}
	self.maid:clean()
end
Server.Destroy = Server.destroy

return Server
