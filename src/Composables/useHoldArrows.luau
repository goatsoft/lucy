--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Holds the gamepad's selection on `target` while `active` is true, so the D-pad and the left
	stick reach its nudge (InputManager.nudge) instead of moving the selection away: a grabbed
	clip the arrows slide, a value being changed. While active, each of target's
	NextSelection* points at target itself (the engine keeps the selection where it is; a
	SelectionBehavior of Stop holds only at a SelectionGroup's edge); after, they are cleared.

		Lucy.useHoldArrows(clip, grabbed)    -- target: a GuiObject, ref or getter

	Games call this rather than setting NextSelection* themselves.
]]
local ARROW_LINKS = { "NextSelectionLeft", "NextSelectionRight", "NextSelectionUp", "NextSelectionDown" }

local function useHoldArrows(target: Reactive.MaybeRef<GuiObject?>, active: Reactive.MaybeRef<boolean>)
	requireOwner("useHoldArrows")
	Reactive.watchEffect(function(onCleanup)
		local gui: GuiObject? = Reactive.toValue(target) :: any
		if not gui or not Reactive.toValue(active) then
			return
		end
		for _, link in ARROW_LINKS do
			(gui :: any)[link] = gui
		end
		onCleanup(function()
			for _, link in ARROW_LINKS do
				if (gui :: any)[link] == gui then
					(gui :: any)[link] = nil
				end
			end
		end)
	end)
end

return useHoldArrows
