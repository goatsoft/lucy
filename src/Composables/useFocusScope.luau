--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

-- Keeps keyboard and gamepad focus inside `options.root` while `active` is true
-- (an InputManager focus scope: { root, defaultFocus }).
local function useFocusScope(app: any, active: Reactive.MaybeRef<boolean>, options: { [string]: any })
	requireOwner("useFocusScope")
	Reactive.watchEffect(function(onCleanup)
		if Reactive.toValue(active) then
			onCleanup(Reactive._untracked(app.input.pushScope, app.input, options))
		end
	end)
end

return useFocusScope
