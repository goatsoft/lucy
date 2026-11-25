--!strict
--[[
	Services: a game's server (or client) modules, started in the order they need each
	other (ADR 0058). Each service says what it needs; Services works out the order,
	refuses a loop, and starts each one so that one failing never stops the rest.

		-- Services/Wallet.luau
		local Wallet = { name = "Wallet", needs = { "Profiles" } }
		function Wallet.init(services)   -- set up, no yielding: services:get("Profiles") is ready
		end
		function Wallet.start(services)  -- may yield (loops, waits); runs on its own thread
		end
		return Wallet

		-- init.server.luau
		local services = Lucy.Services.new()
		services:addFolder(script.Services)   -- every ModuleScript that returns a service
		services:run()

	A service is a table with:
		name    unique; the module's name when added from a folder and not given
		needs   names it uses (optional); they are inited and started before it
		init    fn(services), optional: runs first, in order, and must not yield
		start   fn(services), optional: runs after every init, in order, each on its own
		        thread
	A module that returns something else (a plain helper) is left alone by addFolder.

	run raises if a need is missing or the needs make a loop, naming them; an init that
	errors or yields raises too, naming the service. A start that errors is warned about
	with the service's name and the others carry on.

	options:
		warn   a warner (specs)
]]

local Services = {}
Services.__index = Services

export type Service = {
	name: string?,
	needs: { string }?,
	init: ((services: any) -> ())?,
	start: ((services: any) -> ())?,
	[any]: any,
}

function Services.new(options: { warn: ((...any) -> ())? }?): any
	return setmetatable({
		_byName = {} :: { [string]: Service },
		_order = {} :: { string },
		_ran = false,
		warn = (options and options.warn or warn) :: (...any) -> (),
	}, Services)
end

-- Whether a module's value is a service
function Services.isService(value: any): boolean
	return type(value) == "table"
		and (
			type(value.init) == "function"
			or type(value.start) == "function"
			or type(value.needs) == "table"
		)
end

function Services.add(self: any, service: Service, name: string?): Service
	assert(not self._ran, "[Lucy] Services: add before run")
	local id = service.name or name
	assert(type(id) == "string", "[Lucy] Services: a service needs a name")
	if self._byName[id] then
		error(`[Lucy] Services: two services are called "{id}"`, 2)
	end
	service.name = id
	self._byName[id] = service
	table.insert(self._order, id)
	return service
end

-- Requires every ModuleScript in folder (not its descendants) and adds those that are
-- services. Returns how many were added.
function Services.addFolder(self: any, folder: Instance): number
	local added = 0
	local children = folder:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	for _, child in children do
		if child:IsA("ModuleScript") then
			local value = (require :: any)(child)
			if Services.isService(value) then
				self:add(value, child.Name)
				added += 1
			end
		end
	end
	return added
end

function Services.get(self: any, name: string): any
	local service = self._byName[name]
	if not service then
		error(`[Lucy] Services: no service called "{name}"`, 2)
	end
	return service
end

-- The names in the order they start: every service after what it needs
function Services.order(self: any): { string }
	local out: { string } = {}
	local state: { [string]: string } = {} -- "visiting" | "done"
	local function visit(id: string, path: { string })
		if state[id] == "done" then
			return
		end
		if state[id] == "visiting" then
			table.insert(path, id)
			error(`[Lucy] Services: these need each other in a loop: {table.concat(path, " -> ")}`, 0)
		end
		local service = self._byName[id]
		if not service then
			error(`[Lucy] Services: "{path[#path]}" needs "{id}", which is not added`, 0)
		end
		state[id] = "visiting"
		table.insert(path, id)
		for _, need in service.needs or {} do
			visit(need, path)
		end
		table.remove(path)
		state[id] = "done"
		table.insert(out, id)
	end
	for _, id in self._order do
		visit(id, {})
	end
	return out
end

function Services.run(self: any)
	assert(not self._ran, "[Lucy] Services: run once")
	self._ran = true
	local order = self:order()
	for _, id in order do
		local service = self._byName[id]
		local init = service.init
		if init then
			local thread = coroutine.create(init)
			local ok, err = coroutine.resume(thread, self)
			if not ok then
				error(`[Lucy] Services: "{id}" failed to init: {err}`, 0)
			end
			if coroutine.status(thread) ~= "dead" then
				error(`[Lucy] Services: "{id}" yielded in init; wait in start instead`, 0)
			end
		end
	end
	for _, id in order do
		local service = self._byName[id]
		local start = service.start
		if start then
			task.spawn(function()
				local ok, err = pcall(start, self)
				if not ok then
					self.warn(`[Lucy] Services: "{id}" failed to start: {err}`)
				end
			end)
		end
	end
end

return Services
