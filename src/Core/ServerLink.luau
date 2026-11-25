--!strict
--[[
	ServerLink: app.server, the client half of Lucy's server (ADR 0033).

		local app = Lucy.App.new({ server = true })

		app.state:ref("server.show.phase")   -- what the server keeps in shared.*
		app.state:ref("server.me.coins")     -- what it keeps for this player
		app.server:send("vote", "House")     -- a request; nothing comes back
		local ok = app.server:call("buy", "moonwalk") -- waits for the handler's answer
		app.server:stream("aim", hit)          -- unreliable: may be dropped, the next replaces it
		app.server:onStream("shot", function(from, to) end) -- server:stream(...) from the server

	The link finds the server's remotes ("<namePrefix>Server" in ReplicatedStorage)
	without holding up App.new, tells the server it is ready, and writes everything the
	server sends into app.state under `server`. Treat `server.*` as read only: the next
	update from the server replaces anything written there.

	options (App.new's `server`): true, or
		namePrefix  the server's namePrefix ("Lucy_")
		parent      where to look for the remotes folder (ReplicatedStorage)
		transport   { send(kind, ...), call(name, ...), stream(name, ...)? } instead of
		            remotes (specs); the link's _stream(name, ...) is what arrives
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerLink = {}
ServerLink.__index = ServerLink

type Transport = {
	send: (kind: string, ...any) -> (),
	call: (name: string, ...any) -> (boolean, any),
	stream: ((name: string, ...any) -> ())?,
}

export type ServerLink = typeof(setmetatable(
	{} :: {
		app: any,
		_transport: Transport?,
		_queue: { { n: number, [number]: any } },
		_listeners: { [string]: { (...any) -> () } },
		_connections: { RBXScriptConnection },
		destroyed: boolean?,
	},
	ServerLink
))

local BASE = "server"
local ME = "me"

function ServerLink.new(app: any, options: any): ServerLink
	local opts: { [string]: any } = if type(options) == "table" then options else {}
	local self: ServerLink = setmetatable({} :: any, ServerLink)
	self.app = app
	self._queue = {}
	self._listeners = {}
	self._connections = {}

	if opts.transport then
		self:_connect(opts.transport)
	else
		local parent: Instance = opts.parent or ReplicatedStorage
		local name = (opts.namePrefix or "Lucy_") .. "Server"
		task.spawn(function()
			local folder = parent:WaitForChild(name)
			local sync = folder:WaitForChild("Sync") :: RemoteEvent
			local call = folder:WaitForChild("Call") :: RemoteFunction
			local stream = folder:FindFirstChild("Stream") :: UnreliableRemoteEvent?
			if self.destroyed then
				return
			end
			if stream then
				table.insert(
					self._connections,
					stream.OnClientEvent:Connect(function(name, ...)
						self:_stream(name, ...)
					end)
				)
			end
			table.insert(
				self._connections,
				sync.OnClientEvent:Connect(function(message)
					self:_receive(message)
				end)
			)
			self:_connect({
				send = function(kind: string, ...)
					sync:FireServer(kind, ...)
				end,
				call = function(requestName: string, ...)
					return call:InvokeServer(requestName, ...)
				end,
				stream = if stream
					then function(requestName: string, ...)
						stream:FireServer(requestName, ...)
					end
					else nil,
			})
		end)
	end
	return self
end

function ServerLink._connect(self: ServerLink, transport: Transport)
	self._transport = transport
	transport.send("ready")
	-- Requests made before the remotes were found
	local queued = self._queue
	self._queue = {}
	for _, args in queued do
		transport.send("send", table.unpack(args, 1, args.n))
	end
end

-- Sends a request to the server's handler for `name`. Nothing comes back.
function ServerLink.send(self: ServerLink, name: string, ...)
	local transport = self._transport
	if transport then
		transport.send("send", name, ...)
	else
		table.insert(self._queue, table.pack(name, ...))
	end
end

-- Sends a request and waits for the handler's answer. Raises the server's error.
function ServerLink.call(self: ServerLink, name: string, ...): any
	while not self._transport and not self.destroyed do
		task.wait()
	end
	local transport = self._transport :: Transport
	local ok, result = transport.call(name, ...)
	if not ok then
		error(`[Lucy] server request "{name}" failed: {result}`, 2)
	end
	return result
end

-- Sends a request on the unreliable channel (a handler with unreliable = true). It may be
-- dropped, and is dropped while the link is still connecting: send what the next one replaces.
function ServerLink.stream(self: ServerLink, name: string, ...)
	local transport = self._transport
	if transport and transport.stream then
		transport.stream(name, ...)
	end
end

-- Calls fn(...) whenever the server streams `name` (server:stream). Returns a disconnect.
function ServerLink.onStream(self: ServerLink, name: string, fn: (...any) -> ()): () -> ()
	local list = self._listeners[name]
	if not list then
		list = {}
		self._listeners[name] = list
	end
	table.insert(list, fn)
	return function()
		local current = self._listeners[name]
		if current then
			local index = table.find(current, fn)
			if index then
				table.remove(current, index)
			end
		end
	end
end

-- What arrived on the unreliable channel
function ServerLink._stream(self: ServerLink, name: any, ...)
	if type(name) ~= "string" then
		return
	end
	local list = self._listeners[name]
	if not list then
		return
	end
	for _, fn in table.clone(list) do
		task.spawn(fn, ...)
	end
end

local function apply(state: any, base: string, ops: { any })
	for _, op in ops do
		local path, value = op[1], op[2]
		local target = if path == "" then base else base .. "." .. path
		if value == nil then
			state:remove(target)
		else
			state:set(target, value)
		end
	end
end

-- Applies a message from the server: { shared = ops?, me = ops? }.
function ServerLink._receive(self: ServerLink, message: any)
	if type(message) ~= "table" then
		return
	end
	local state = self.app.state
	state:batch(function()
		local shared = message.shared
		if type(shared) == "table" then
			local rest = {}
			for _, op in shared do
				local path, value = op[1], op[2]
				if path == "" then
					-- The whole shared tree: keep this player's own state beside it
					local whole: { [any]: any } = if type(value) == "table" then table.clone(value) else {}
					if whole[ME] ~= nil then
						warn(
							`[Lucy] the server's shared.{ME} is hidden by server.{ME}, the player's own state`
						)
					end
					whole[ME] = state:get(BASE .. "." .. ME)
					state:set(BASE, whole)
				elseif path == ME or string.sub(path, 1, #ME + 1) == ME .. "." then
					-- Hidden by the player's own state, as above
					continue
				else
					table.insert(rest, op)
				end
			end
			apply(state, BASE, rest)
		end
		local me = message.me
		if type(me) == "table" then
			apply(state, BASE .. "." .. ME, me)
		end
	end)
end

function ServerLink.destroy(self: ServerLink)
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
	self._listeners = {}
end
ServerLink.Destroy = ServerLink.destroy

return ServerLink
