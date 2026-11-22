--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local requireOwner = require(script.Parent.requireOwner)

-- useSize leaves out a change smaller than this, in points
local SIZE_NOISE = 0.01

--[[
	The size of a GUI object in the units you lay it out in: its AbsoluteSize
	without the UIScales on it and above it (Lucy scales every scene to the
	device), so it compares with the offsets you write. A getter that follows the
	object as it resizes and as the scene rescales; Vector2.zero while there is no
	object or it is not laid out yet. `target` may be a ref or a getter.

	For a size that depends on room only known once laid out (cards as tall as
	the body under a header), bind to it instead of measuring by hand. A change
	of less than a hundredth of a point is left out.
]]
local function useSize(target: Reactive.MaybeRef<GuiObject?>): () -> Vector2
	requireOwner("useSize")
	local size = Reactive.ref(Vector2.zero)
	local last = Vector2.zero
	local function set(value: Vector2)
		-- A change under SIZE_NOISE is left out: in a scaled panel, layout moves an object's size
		-- back and forth by a tiny fraction of a point as it settles, and following that made
		-- layouts that read the size chase it round and round
		local moved = value - last
		if
			math.abs(moved.X) >= SIZE_NOISE
			or math.abs(moved.Y) >= SIZE_NOISE
			or (value == Vector2.zero) ~= (last == Vector2.zero)
		then
			last = value
			size(value)
		end
	end
	Reactive.watchEffect(function(onCleanup)
		local gui: GuiObject? = Reactive.toValue(target) :: any
		if not gui then
			set(Vector2.zero)
			return
		end
		local function measure()
			local scale = math.max(Scroll.scaleOf(gui), 0.001)
			set(gui.AbsoluteSize / scale)
		end
		local resized = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		local moved = gui.AncestryChanged:Connect(measure)
		onCleanup(function()
			resized:Disconnect()
			moved:Disconnect()
		end)
		Reactive.untrack(measure)
	end)
	return function(): Vector2
		return size()
	end
end

return useSize
