--!strict
--[[
	Server: the server half of Lucy (ADR 0033). The same store as the App's, on the
	server, sending what players may see to their Apps and taking their requests.

		local server = Lucy.Server.new({ state = { shared = { show = { phase = "Signup" } } } })

		server.state:set("shared.show.phase", "Live")      -- every player sees server.show.phase
		server:player(player):set("coins", 50)             -- this player sees server.me.coins
		server.state:set("rounds.seed", 1234)              -- stays on the server

		server:handle("signup", function(player, genre)    -- app.server:send / call("signup", ...)
			if type(genre) ~= "string" then return false end -- check everything a client sends
			...
		end)

	What replicates:
		shared.*            to every player, at server.* in their App
		players.u<UserId>.* to that player only, at server.me.* in their App
		anything else       nowhere

	Once a frame the server compares what changed with what it last sent each player
	and sends only the differences. The store's copies share every table that did not
	change, so unchanged parts of the tree cost one comparison. A player gets everything
	when their App says it is ready.

	Wire format (one message per player per frame):
		{ shared = ops?, me = ops? }, each op { path, value } to set or { path } to remove;
		path "" is the whole root. Keys must not contain dots.

	options:
		state       the starting tree (shared and players are added if missing)
		namePrefix  the remotes folder is "<namePrefix>Server" ("Lucy_")
		parent      where the remotes folder goes (ReplicatedStorage)
		players     false to skip the Players service (specs); joins come from _join
		transport   { send(player, message) } instead of remotes (specs)
		autoFlush   false to flush only when :flush() is called (specs)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AppState = require(script.Parent.AppState)
local Maid = require(script.Parent.Maid)

local Server = {}
Server.__index = Server

export type Op = { any }
export type Message = { shared: { Op }?, me: { Op }? }

type PlayerEntry = {
	path: string,
	ready: boolean,
	dirty: boolean,
	lastShared: any,
	lastMe: any,
	stop: () -> (),
}

export type Server = typeof(setmetatable(
	{} :: {
		state: AppState.AppState,
		namePrefix: string,
		maid: Maid.Maid,
		_players: { [any]: PlayerEntry },
		_handlers: { [string]: (...any) -> ...any },
		_sharedDirty: boolean,
		_transport: { send: (player: any, message: Message) -> () },
		destroyed: boolean?,
	},
	Server
))

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

local function remotes(self: Server, parent: Instance): { send: (any, Message) -> () }
	local folder = Instance.new("Folder")
	folder.Name = self.namePrefix .. "Server"
	local sync = Instance.new("RemoteEvent")
	sync.Name = "Sync"
	sync.Parent = folder
	local call = Instance.new("RemoteFunction")
	call.Name = "Call"
	call.Parent = folder

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
	folder.Parent = parent
	self.maid:give(folder)

	return {
		send = function(player: any, message: Message)
			sync:FireClient(player, message)
		end,
	}
end

function Server.new(options: { [string]: any }?): Server
	local opts: { [string]: any } = options or {}
	local self: Server = setmetatable({} :: any, Server)
	self.namePrefix = opts.namePrefix or "Lucy_"
	self.maid = Maid.new()
	self._players = {}
	self._handlers = {}
	self._sharedDirty = false

	local initial: { [string]: any } = table.clone(opts.state or {})
	initial.shared = initial.shared or {}
	initial.players = initial.players or {}
	self.state = AppState.new(initial)
	self.maid:give(self.state)

	self._transport = opts.transport or remotes(self, opts.parent or ReplicatedStorage)

	self.maid:give(self.state:subscribe("shared", function()
		self._sharedDirty = true
	end))

	if opts.autoFlush ~= false then
		self.maid:give(RunService.Heartbeat:Connect(function()
			self:flush()
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
-- back to app.server:call. Check every argument: a client can send anything.
function Server.handle(self: Server, name: string, fn: (player: any, ...any) -> ...any): () -> ()
	if self._handlers[name] then
		error(`[Lucy] the server already handles "{name}"`, 2)
	end
	self._handlers[name] = fn
	return function()
		if self._handlers[name] == fn then
			self._handlers[name] = nil
		end
	end
end

-- Sends each ready player what changed since the last flush. Runs every frame unless
-- autoFlush is false.
function Server.flush(self: Server)
	local sharedDirty = self._sharedDirty
	self._sharedDirty = false
	local shared = if sharedDirty then self.state:get("shared") else nil
	for player, entry in self._players do
		if not entry.ready or not (sharedDirty or entry.dirty) then
			continue
		end
		local message: Message = {}
		if sharedDirty then
			local ops = {}
			diff(entry.lastShared, shared, "", ops)
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
		self:_join(player)
	end
	local entry = self._players[player]
	entry.ready = true
	entry.dirty = false
	entry.lastShared = self.state:get("shared")
	entry.lastMe = self.state:get(entry.path)
	self._transport.send(player, {
		shared = { { "", entry.lastShared or {} } },
		me = { { "", entry.lastMe or {} } },
	})
end

-- A request from a player: (true, results...) from its handler, or (false, reason).
function Server._request(self: Server, player: any, name: any, ...): (boolean, any)
	if not self._players[player] then
		return false, "not in the game"
	end
	if type(name) ~= "string" then
		return false, "a request needs a name"
	end
	local handler = self._handlers[name]
	if not handler then
		return false, `no handler for "{name}"`
	end
	local results = table.pack(pcall(handler, player, ...))
	if not results[1] then
		warn(`[Lucy] server handler "{name}" failed: {results[2]}`)
		return false, tostring(results[2])
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
