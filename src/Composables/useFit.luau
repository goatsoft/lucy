--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local useSize = require(script.Parent.useSize)
local requireOwner = require(script.Parent.requireOwner)

-- The smallest scale useFit goes down to when the caller gives no min
local FIT_MIN = 0.6
-- How much room to spare before a fitted object grows again. Text drawn smaller does not
-- measure exactly in proportion, so each scale changes the measured width a little; following
-- every change rocked the scale back and forth (0.89, 0.93, 0.90) and poked out of the room
-- on the high swings. It shrinks at once when it is wider than the room, and grows only past this
local GROW_SLACK = 0.04

--[[
	The scale that makes a GUI object fit the width its parent has (less the parent's
	padding): 1 while it fits, less when it is wider, never under `min` (FIT_MIN, 0.6, when
	left out) so it stays readable. Bind it to a UIScale on the object:

		Element.new("UIScale", { Scale = Lucy.useFit(row, { min = 0.5 }), Parent = row })

	The object should size itself to its content (AutomaticSize) and its parent should have
	a width of its own; a parent that sizes to the object would shrink with it. Text's and
	Stack's `fit` do this for you. `target` may be a ref or a getter.
]]
local function useFit(target: Reactive.MaybeRef<GuiObject?>, options: { min: number? }?): () -> number
	requireOwner("useFit")
	local min = if options and type(options.min) == "number" then options.min else FIT_MIN
	-- The object's own size: useSize leaves out the scales on it, this one included
	local own = useSize(target)
	local parent = Reactive.ref(nil :: GuiObject?)
	Reactive.watchEffect(function(onCleanup)
		local gui: GuiObject? = Reactive.toValue(target) :: any
		if not gui then
			parent(nil)
			return
		end
		local function look()
			local p = gui.Parent
			parent(if p and p:IsA("GuiObject") then p else nil)
		end
		local moved = gui.AncestryChanged:Connect(look)
		onCleanup(function()
			moved:Disconnect()
		end)
		Reactive.untrack(look)
	end)
	local room = useSize(parent)
	-- The parent's padding, left and right: offsets in layout units, and the share of its width
	local inset = Reactive.ref(Vector2.zero)
	Reactive.watchEffect(function(onCleanup)
		local p = parent()
		if not p then
			inset(Vector2.zero)
			return
		end
		local watching: RBXScriptConnection? = nil
		local function read()
			if watching then
				watching:Disconnect()
				watching = nil
			end
			local pad = p:FindFirstChildOfClass("UIPadding")
			if not pad then
				inset(Vector2.zero)
				return
			end
			local function measure()
				inset(
					Vector2.new(
						pad.PaddingLeft.Offset + pad.PaddingRight.Offset,
						pad.PaddingLeft.Scale + pad.PaddingRight.Scale
					)
				)
			end
			watching = pad.Changed:Connect(measure)
			measure()
		end
		local added = p.ChildAdded:Connect(read)
		local removed = p.ChildRemoved:Connect(read)
		onCleanup(function()
			added:Disconnect()
			removed:Disconnect()
			if watching then
				watching:Disconnect()
			end
		end)
		Reactive.untrack(read)
	end)
	local floor = math.min(min, 1)
	local last = 1
	local scale = Reactive.computed(function(): number
		local natural = own().X
		local width = room().X
		if natural <= 0 or width <= 0 then
			last = 1
			return 1
		end
		local pad = inset()
		local free = width * (1 - pad.Y) - pad.X
		local want = math.clamp(free / natural, floor, 1)
		local drawn = natural * last
		-- Shrink now when it is wider than the room at the scale it has; grow only with clearly
		-- room to spare (the room grew, or the words got shorter)
		local overflowing = drawn > free + 0.5
		local roomy = want > last and drawn < free * (1 - GROW_SLACK)
		if overflowing or roomy then
			last = want
		end
		return last
	end)
	return function(): number
		return scale()
	end
end

return useFit
