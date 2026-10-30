--!strict
--[[
	Signal: a tiny synchronous event, used where an RBXScriptSignal is not available
	(pure-Luau objects like AppState and Theme). Handlers run in connection order;
	an error in one handler is reported and does not stop the others.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type Handler = (...any) -> ...any
type Entry = { fn: Handler, conn: Connection }

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _entries: { Entry } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _entries = {} }, Signal)
end

function Signal.Connect(self: Signal, fn: Handler): Connection
	local entries = self._entries
	local conn = { Connected = true } :: any
	local entry: Entry = { fn = fn, conn = conn }
	function conn.Disconnect(c: Connection)
		if not c.Connected then
			return
		end
		c.Connected = false
		local index = table.find(entries, entry)
		if index then
			table.remove(entries, index)
		end
	end
	table.insert(entries, entry)
	return conn
end

function Signal.Once(self: Signal, fn: Handler): Connection
	local conn: Connection
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal.Fire(self: Signal, ...: any)
	-- Snapshot so handlers may connect or disconnect while firing.
	local snapshot = table.clone(self._entries)
	for _, entry in snapshot do
		if entry.conn.Connected then
			local ok, err = pcall(entry.fn, ...)
			if not ok then
				warn("[Lucy] signal handler error: " .. tostring(err))
			end
		end
	end
end

function Signal.DisconnectAll(self: Signal)
	for _, entry in table.clone(self._entries) do
		entry.conn:Disconnect()
	end
end

return Signal
