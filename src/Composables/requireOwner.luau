--!strict
--[[
	Every composable needs an owner (a component's render, an effect or an effectScope):
	anything it creates stops with that owner. Called with no owner, it errors at the
	caller, since nothing would ever stop it.
]]
local Reactive = require(script.Parent.Parent.Core.Reactive)

local function requireOwner(name: string)
	if not Reactive._hasOwner() then
		error(`[Lucy] {name} needs an owner: call it in a component's render, an effect or an effectScope`, 3)
	end
end

return requireOwner
