--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Runs `setup` each time `condition` (a ref, getter or value) turns true, and
	cleans up what it made when it turns false or the owner stops. `setup` may
	return a cleanup function or an RBXScriptConnection, and may call onCleanup or
	make effects of its own. Its reads are not tracked, and a getter that reads
	something new but stays true does not restart it: only `condition` turning
	true or false does.

		Lucy.useWhile(function() return app:modalOpen() end, function()
			return app.actions:disable("gameplay", "movement")
		end)
]]
local function useWhile(condition: Reactive.MaybeRef<boolean>, setup: () -> any)
	requireOwner("useWhile")
	-- A boolean the effect follows, so only a flip reruns it
	local active = Reactive.computed(function(): boolean
		return Reactive.toValue(condition) and true or false
	end)
	Reactive.watchEffect(function(onCleanup)
		if not active() then
			return
		end
		local scope = Reactive.effectScope(true)
		local result = Reactive.untrack(function()
			return scope:run(setup)
		end)
		if result ~= nil and type(result) ~= "function" and typeof(result) ~= "RBXScriptConnection" then
			scope:stop()
			error("[Lucy] useWhile: setup returns a cleanup function, a connection or nothing", 0)
		end
		onCleanup(function()
			scope:stop()
			if type(result) == "function" then
				result()
			elseif typeof(result) == "RBXScriptConnection" then
				result:Disconnect()
			end
		end)
	end)
end

return useWhile
