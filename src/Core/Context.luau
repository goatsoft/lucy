--!strict
--[[
	Context: holds the "current" App so components can be created without passing
	`app` every time. Kept separate from App to avoid require cycles.
	Tests always pass `app` explicitly so they never depend on this global.
]]

local Context = {}

local current: any = nil

function Context.setCurrent(app: any)
	current = app
end

function Context.getCurrent(): any
	return current
end

function Context.clearIf(app: any)
	if current == app then
		current = nil
	end
end

return Context
