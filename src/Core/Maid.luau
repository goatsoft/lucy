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
-- A maid keeps its tasks in its own array part: one table per maid.
export type Maid = {
	give: <T>(self: Maid, item: T) -> T,
	clean: (self: Maid) -> (),
	destroy: (self: Maid) -> (),
	Destroy: (self: Maid) -> (),
}

function Maid.new(): Maid
	return setmetatable({}, Maid) :: any
end

function Maid.give<T>(self: Maid, item: T): T
	table.insert(self :: any, item)
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

-- Tasks being cleaned wait here, so cleaning builds no table. A clean started
-- by a cleanup stacks its tasks above the ones still waiting.
local stack: { any } = {}
local top = 0

function Maid.clean(self: Maid)
	local tasks: { any } = self :: any
	local count = #tasks
	if count == 0 then
		return
	end
	-- Moved out first: anything given during the clean waits for the next one.
	local base = top
	for i = 1, count do
		stack[base + i] = tasks[i]
		tasks[i] = nil
	end
	top = base + count
	-- In reverse, so things are torn down in the opposite order they were made.
	for i = base + count, base + 1, -1 do
		local item = stack[i]
		stack[i] = nil
		local ok: boolean, err: any = pcall(cleanup, item)
		if not ok then
			warn("[Lucy] maid cleanup error: " .. tostring(err))
		end
	end
	top = base
end

Maid.Destroy = Maid.clean
Maid.destroy = Maid.clean

return Maid
