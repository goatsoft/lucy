--!strict
--[[
	Scroll: helpers for ScrollingFrames.

		Scroll.offsetFor(position, view, top, bottom, margin, extent?) -- pure, see below
		Scroll.reveal(object, margin?, only?)
		                                -- scrolls every ScrollingFrame above object to show it,
		                                -- or only the one given (a row's own scroller, so the
		                                -- page it sits in stays where the player put it)
		Scroll.scaleOf(object)          -- the product of the UIScales above object
		Scroll.whenNear(object, callback, overscan?)
		                                -- calls back once, the first time object shows and is
		                                -- near what the ScrollingFrame around it shows; returns
		                                -- a function that stops it looking
		Scroll.along(object, axis)      -- the nearest ScrollingFrame above object that scrolls
		                                -- along "X" or "Y" (its canvas is bigger than it there)
		Scroll.stickStep(tilt, view, dt) -- pure: how far one axis of the right stick scrolls
		Scroll.byStick(object, stick, dt)
		                                -- scrolls round object with the right stick: up and down
		                                -- the nearest scroller that scrolls that way, left and
		                                -- right the nearest that scrolls sideways; returns the
		                                -- scrollers it moved

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
		-- only while the span's top still shows from the end (a span taller than the view)
		local toEnd = last - target < near and top >= last
		-- Going forward, the end first: in a list that only just overflows both ends are near, and
		-- the start would leave the span it scrolled for under the end's fade
		if toEnd and (target > position or target >= near) then
			target = last
		elseif target < near then
			target = 0
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

-- The right stick (InputManager): nothing under the deadzone, then up to stickSpeed views a
-- second at full tilt, gently at first (squared) so a small tilt reads a line at a time.
Scroll.stickDeadzone = 0.2
Scroll.stickSpeed = 1.6

function Scroll.along(object: Instance, axis: string): ScrollingFrame?
	local node: Instance? = object.Parent
	while node do
		if node:IsA("ScrollingFrame") and node.ScrollingEnabled then
			local frame = node :: ScrollingFrame
			local direction = frame.ScrollingDirection
			local allowed = direction == Enum.ScrollingDirection.XY
				or (axis == "X" and direction == Enum.ScrollingDirection.X)
				or (axis == "Y" and direction == Enum.ScrollingDirection.Y)
			-- against the frame's whole size: the other way's scroll bar narrows the window, which
			-- is not more to see
			local room = if axis == "X"
				then frame.AbsoluteCanvasSize.X - frame.AbsoluteSize.X
				else frame.AbsoluteCanvasSize.Y - frame.AbsoluteSize.Y
			if allowed and room > 1 then
				return frame
			end
		end
		node = node.Parent
	end
	return nil
end

function Scroll.stickStep(tilt: number, view: number, dt: number): number
	local amount = math.abs(tilt)
	if amount < Scroll.stickDeadzone then
		return 0
	end
	local t = math.min(1, (amount - Scroll.stickDeadzone) / (1 - Scroll.stickDeadzone))
	return math.sign(tilt) * t * t * Scroll.stickSpeed * view * dt
end

function Scroll.byStick(object: GuiObject, stick: Vector2, dt: number): { ScrollingFrame }
	local moved: { ScrollingFrame } = {}
	for _, axis in { "X", "Y" } do
		local frame = Scroll.along(object, axis)
		if not frame then
			continue
		end
		local canvas = frame.CanvasPosition
		local window = frame.AbsoluteWindowSize
		local extent = frame.AbsoluteCanvasSize
		local position = canvas
		if axis == "X" then
			-- right goes on along the row
			local x = canvas.X + Scroll.stickStep(stick.X, window.X, dt)
			position = Vector2.new(math.clamp(x, 0, math.max(0, extent.X - window.X)), canvas.Y)
		else
			-- the stick's Y is up: up goes back towards the top
			local y = canvas.Y - Scroll.stickStep(stick.Y, window.Y, dt)
			position = Vector2.new(canvas.X, math.clamp(y, 0, math.max(0, extent.Y - window.Y)))
		end
		if position ~= canvas then
			frame.CanvasPosition = position
			if not table.find(moved, frame) then
				table.insert(moved, frame)
			end
		end
	end
	return moved
end

-- How many views beyond each edge of what a scroll area shows count as near (whenNear).
Scroll.overscan = 1

-- What hides `object`: itself or the nearest thing above it that is not visible, or a gui that
-- is off. Nil when it shows. False when it is in no gui at all.
local function hiddenBy(object: Instance): (Instance | boolean)?
	local node: Instance? = object
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return node
		end
		if node:IsA("LayerCollector") then
			return if node.Enabled then nil else node
		end
		node = node.Parent
	end
	return false
end

-- True when `object` (which shows) is within `overscan` views of what `scroller` shows.
local function isNear(object: GuiObject, scroller: ScrollingFrame?, overscan: number): boolean
	local from, size = object.AbsolutePosition, object.AbsoluteSize
	if size.X <= 0 and size.Y <= 0 then
		return false -- not laid out yet (a new frame sits at 0, 0, which would read as in view)
	end
	if not scroller then
		return true
	end
	local window = scroller.AbsoluteWindowSize
	if window.X <= 0 or window.Y <= 0 then
		return false -- not laid out yet
	end
	local origin = scroller.AbsolutePosition
	local pad = window * overscan
	return from.X + size.X >= origin.X - pad.X
		and from.X <= origin.X + window.X + pad.X
		and from.Y + size.Y >= origin.Y - pad.Y
		and from.Y <= origin.Y + window.Y + pad.Y
end

--[[
	Calls `callback` once, the first time `object` is shown (it and everything above it visible,
	in a gui that is on) and within `overscan` views (Scroll.overscan when left out) of what the
	nearest ScrollingFrame around it shows. With no ScrollingFrame around it: as soon as it shows.
	Returns a function that stops it looking; it stops by itself once it has called back.

	`object` needs a size of its own: something with no size is taken as not laid out yet. It
	looks when made and then on the engine's signals: the object moved, changed size, was shown
	or was put somewhere, what hid it showed, or the scroll area scrolled or changed size. For
	content built as the player scrolls to it (Core/Deferred's "intersect", Lucy.useIntersect).
]]
function Scroll.whenNear(object: GuiObject, callback: () -> (), overscan: number?): () -> ()
	local reach = overscan or Scroll.overscan
	local connections: { RBXScriptConnection } = {}
	-- The scroll area and the hidden things above the object, each followed once
	local followed: { [Instance]: RBXScriptConnection } = {}
	local stopped = false
	-- Reading the object's place can make the engine lay it out there and then, which fires the
	-- signals this listens to: a look that starts inside another one is dropped
	local looking = false

	local function stop()
		if stopped then
			return
		end
		stopped = true
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, connection in followed do
			connection:Disconnect()
		end
		table.clear(connections)
		table.clear(followed)
	end

	local look: () -> ()

	local function decide(): boolean
		local hider = hiddenBy(object)
		if hider ~= nil then
			-- Hidden by something above it (a tab not picked, a closed sheet): look again when
			-- that shows. Its place may not change then, so no other signal would say so.
			if typeof(hider) == "Instance" and hider ~= object and not followed[hider] then
				local property = if hider:IsA("LayerCollector") then "Enabled" else "Visible"
				followed[hider] = hider:GetPropertyChangedSignal(property):Connect(look)
			end
			return false
		end
		local scroller = object:FindFirstAncestorWhichIsA("ScrollingFrame")
		if scroller and not followed[scroller] then
			followed[scroller] = scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(look)
			-- and on every scroll: the engine moves what is past the visible part lazily, so an
			-- object just beyond it often hears nothing of a scroll (its AbsolutePosition does not
			-- change), and a list scrolled by gamepad focus stopped where nothing new was built
			table.insert(connections, scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(look))
		end
		return isNear(object, scroller, reach)
	end

	function look()
		if stopped or looking then
			return
		end
		looking = true
		local near = decide()
		looking = false
		if near and not stopped then
			stop()
			callback()
		end
	end

	connections = {
		object:GetPropertyChangedSignal("AbsolutePosition"):Connect(look),
		object:GetPropertyChangedSignal("AbsoluteSize"):Connect(look),
		object:GetPropertyChangedSignal("Visible"):Connect(look),
		object.AncestryChanged:Connect(look),
	}
	look()
	return stop
end

return Scroll
