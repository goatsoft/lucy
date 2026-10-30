--!strict
--[[
	Scroll: helpers for ScrollingFrames.

		Scroll.offsetFor(position, view, top, bottom, margin) -- pure, see below
		Scroll.reveal(object, margin?)  -- scrolls every ScrollingFrame above object to show it
		Scroll.scaleOf(object)          -- the product of the UIScales above object

	The engine scrolls to the gamepad selection by itself, but focus moved by Lucy
	(Tab, arrow keys) does not, so InputManager.markFocus calls reveal while the
	player is navigating.

	CanvasPosition, AbsolutePosition and AbsoluteWindowSize are all in screen
	pixels (after UIScale), so reveal needs no scale; scaleOf turns a measured
	AbsoluteSize back into the offsets a Size is written in.
]]

local Scroll = {}

local DEFAULT_MARGIN = 8

--[[
	The canvas position along one axis that shows the span top..bottom (in canvas
	coordinates) inside a view of size `view` currently scrolled to `position`,
	with `margin` pixels to spare. Unchanged when the span is already in view; a
	span taller than the view shows its top.
]]
function Scroll.offsetFor(
	position: number,
	view: number,
	top: number,
	bottom: number,
	margin: number?
): number
	local m = margin or 0
	if top - m < position then
		return math.max(0, top - m)
	end
	if bottom + m > position + view then
		return math.max(0, math.min(top - m, bottom + m - view))
	end
	return position
end

function Scroll.scaleOf(object: Instance): number
	local scale = 1
	local node: Instance? = object
	while node do
		local uiScale = node:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale *= uiScale.Scale
		end
		node = node.Parent
	end
	return scale
end

function Scroll.reveal(object: GuiObject, margin: number?)
	local m = margin or DEFAULT_MARGIN
	local node: Instance? = object.Parent
	while node do
		if node:IsA("ScrollingFrame") then
			local frame = node :: ScrollingFrame
			local canvas = frame.CanvasPosition
			local window = frame.AbsoluteWindowSize
			local origin = frame.AbsolutePosition
			local top = object.AbsolutePosition - origin + canvas
			local bottom = top + object.AbsoluteSize
			local x = Scroll.offsetFor(canvas.X, window.X, top.X, bottom.X, m)
			local y = Scroll.offsetFor(canvas.Y, window.Y, top.Y, bottom.Y, m)
			if x ~= canvas.X or y ~= canvas.Y then
				frame.CanvasPosition = Vector2.new(x, y)
			end
		end
		node = node.Parent
	end
end

return Scroll
