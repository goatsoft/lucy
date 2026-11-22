--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

-- Puts `handler` on the back stack (the back keys) while `active` is true.
-- The handler returns true when it consumed the back press.
local function useBackHandler(app: any, active: Reactive.MaybeRef<boolean>, handler: () -> boolean?)
	requireOwner("useBackHandler")
	Reactive.watchEffect(function(onCleanup)
		if Reactive.toValue(active) then
			onCleanup(Reactive._untracked(app.input.pushBack, app.input, handler))
		end
	end)
end

return useBackHandler
