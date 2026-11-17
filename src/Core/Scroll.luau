--!strict
--[[
	Scroll: helpers for ScrollingFrames.

		Scroll.offsetFor(position, view, top, bottom, margin, extent?) -- pure, see below
		Scroll.reveal(object, margin?, only?)
		                                -- scrolls every ScrollingFrame above object to show it,
		                                -- or only the one given (a row's own scroller, so the
		                                -- page it sits in stays where the player put it)
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

-- A scroll that would stop within this much of a view from the start or the end of the canvas
-- goes all the way there (offsetFor with an extent).
Scroll.snap = 0.25

--[[
	The canvas position along one axis that shows the span top..bottom (in canvas
	coordinates) inside a view of size `view` currently scrolled to `position`,
	with `margin` pixels to spare. Unchanged when the span is already in view; a
	span taller than the view shows its top.

	With `extent` (the canvas's length), a scroll that would stop within a quarter of a view
	(Scroll.snap) of the start or the end goes all the way there: what sits above the first
	control (a heading, a card nothing can select) or under the last comes into view with it,
	where focus alone would never bring it back.
]]
function Scroll.offsetFor(
	position: number,
	view: number,
	top: number,
	bottom: number,
	margin: number?,
	extent: number?
): number
	local m = margin or 0
	local target = position
	if top - m < position then
		target = math.max(0, top - m)
	elseif bottom + m > position + view then
		target = math.max(0, math.min(top - m, bottom + m - view))
	end
	if extent ~= nil and target ~= position then
		local near = view * Scroll.snap
		local last = math.max(0, extent - view)
		if target < near then
			target = 0
		elseif last - target < near and top >= last then
			-- only while the span's top still shows from the end (a span taller than the view)
			target = last
		end
	end
	return target
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

function Scroll.reveal(object: GuiObject, margin: number?, only: ScrollingFrame?)
	local m = margin or DEFAULT_MARGIN
	local node: Instance? = object.Parent
	while node do
		if node:IsA("ScrollingFrame") and (only == nil or node == only) then
			local frame = node :: ScrollingFrame
			local canvas = frame.CanvasPosition
			local window = frame.AbsoluteWindowSize
			local origin = frame.AbsolutePosition
			local top = object.AbsolutePosition - origin + canvas
			local bottom = top + object.AbsoluteSize
			local extent = frame.AbsoluteCanvasSize
			local x = Scroll.offsetFor(canvas.X, window.X, top.X, bottom.X, m, extent.X)
			local y = Scroll.offsetFor(canvas.Y, window.Y, top.Y, bottom.Y, m, extent.Y)
			if x ~= canvas.X or y ~= canvas.Y then
				frame.CanvasPosition = Vector2.new(x, y)
			end
		end
		node = node.Parent
	end
end

return Scroll
