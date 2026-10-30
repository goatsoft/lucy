--!strict
--[[
	Maid: collects things that need cleaning up and cleans them in one call.
	Accepts Instances, RBXScriptConnections, Signal connections, functions,
	threads, and any table with a Destroy/destroy/Disconnect method.
]]

local Maid = {}
Maid.__index = Maid

-- Spelled out rather than inferred: a generic method inside an inferred
-- metatable type does not survive being copied into other modules' types.
export type Maid = {
	_tasks: { any },
	give: <T>(self: Maid, item: T) -> T,
	clean: (self: Maid) -> (),
	destroy: (self: Maid) -> (),
	Destroy: (self: Maid) -> (),
}

function Maid.new(): Maid
	return setmetatable({ _tasks = {} }, Maid) :: any
end

function Maid.give<T>(self: Maid, item: T): T
	table.insert(self._tasks, item)
	return item
end

local function cleanup(item: any)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.destroy) == "function" then
			item:destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Maid.clean(self: Maid)
	-- Clean in reverse so things are torn down in the opposite order they were made.
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local ok: boolean, err: any = pcall(cleanup, tasks[i])
		if not ok then
			warn("[Lucy] maid cleanup error: " .. tostring(err))
		end
	end
end

Maid.Destroy = Maid.clean
Maid.destroy = Maid.clean

return Maid
