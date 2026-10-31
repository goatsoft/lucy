--!strict
--[[
	ScrollArea: a region that scrolls when its content does not fit.

		ScrollArea.new({
			direction = "vertical",   -- vertical | horizontal | both
			size = UDim2,             -- fills the parent when left out
			maxHeight = 300,          -- optional: fit the content up to this height, then scroll
			padding = "Space4",       -- optional: a spacing token, pixels or a UDim
			scrollbar = "hover",      -- hover | auto | always | scroll | glimpse
			hideDelay = 0.6,          -- seconds the bar stays after scrolling (scroll, hover, glimpse)
			fade = true,              -- true | false | "content" (see below)
			children = { ... },       -- instances, handles or functions
			visible = true,
			Parent = frame,
		})

	handle.Instance is the ScrollingFrame (a CanvasGroup around it with
	fade = "content"); handle.frame is always the ScrollingFrame, and
	handle.content is the frame inside it that holds the children. It lays out nothing itself: put a Stack inside to
	arrange a list. maxHeight takes a number, a ref or a getter; with it, the
	area keeps the width from `size` (or fills the parent) and its height
	follows the content up to the cap.

	Gamepad selection moves through the children and the engine scrolls to it;
	focus moved with Tab or the arrow keys is scrolled into view by the
	InputManager (Core/Scroll). When it scrolls and holds nothing selectable
	(rules text, say), the area itself can be selected, so a gamepad can still
	scroll it.

	Scrollbar visibility, per the axis that scrolls:
		auto     while the content overflows
		always   always, overflowing or not
		scroll   while the player scrolls (wheel, drag, touch, right stick)
		hover    while scrolling, or while the mouse is over it (like scroll on
		         touch and gamepad, which have no hover)
		glimpse  briefly when the mouse enters, and while scrolling
	The bar is hidden by fading it (tag ui-scroll-bar-visible), so the space it
	takes stays put and the content does not move when it shows.

	Each edge with more to scroll past fades into the surface behind it, so a
	control cut by the edge reads as continuing. The fade takes the colour and
	transparency of the nearest ancestor with a visible background (a Panel's
	card, a Select's popover, a game's own frame), else $Background, and follows
	it through theme and transparency changes. handle.fades holds them by side
	(top, bottom, left, right); fade = false leaves them out.

	fade = "content" fades the content itself instead: the window sits in a
	CanvasGroup with a UIGradient, so it works over see-through panels and
	pictures. A CanvasGroup costs texture memory (width x height x 4 bytes at
	the screen's density) and Roblox blurs every CanvasGroup on screen once
	their total passes its budget, so it is opt-in. Only the scrolling axis
	fades (top and bottom for "both").

	State keys: visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)

local ScrollArea = {}

-- How far an edge fade reaches into the area, in px.
ScrollArea.fadeSize = 16

local OUT_SIZE = Element.out("AbsoluteSize")
local OUT_CANVAS = Element.out("AbsoluteCanvasSize")
local OUT_WINDOW = Element.out("AbsoluteWindowSize")
local OUT_POSITION = Element.out("CanvasPosition")
local ON_SCROLL = Element.changed("CanvasPosition")
local ON_ENTER = Element.on("MouseEnter")
local ON_LEAVE = Element.on("MouseLeave")

ScrollArea.scrollbars = { "hover", "auto", "always", "scroll", "glimpse" }

type Axis = {
	scrolling: Enum.ScrollingDirection,
	automatic: Enum.AutomaticSize,
	content: UDim2,
	holder: UDim2,
	x: boolean,
	y: boolean,
}

-- Roblox lets an auto-sized object grow only as far as its nearest fixed-size
-- ancestor, and inside a ScrollingFrame with an automatic canvas that is the
-- window: wrapped text could never be taller than what shows. So the content sits
-- in a holder this long along each scrolling axis, and the canvas follows the
-- content's measured size instead.
local REACH = 100000

local DIRECTIONS: { [string]: Axis } = {
	vertical = {
		scrolling = Enum.ScrollingDirection.Y,
		automatic = Enum.AutomaticSize.Y,
		content = UDim2.fromScale(1, 0),
		holder = UDim2.new(1, 0, 0, REACH),
		x = false,
		y = true,
	},
	horizontal = {
		scrolling = Enum.ScrollingDirection.X,
		automatic = Enum.AutomaticSize.X,
		content = UDim2.fromScale(0, 1),
		holder = UDim2.new(0, REACH, 1, 0),
		x = true,
		y = false,
	},
	both = {
		scrolling = Enum.ScrollingDirection.XY,
		automatic = Enum.AutomaticSize.XY,
		content = UDim2.fromScale(0, 0),
		holder = UDim2.fromOffset(REACH, REACH),
		x = true,
		y = true,
	},
}

ScrollArea.rules = {
	{
		selector = ".ui-scroll-area",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarImageTransparency = 1 },
	},
	{
		selector = ".ui-scroll-area.ui-scroll-bar-visible",
		priority = 1,
		properties = { ScrollBarImageTransparency = 0 },
	},
	{
		selector = ".ui-scroll-area-content",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	-- Edge fades take their colour from the surface they sit on, in code.
	{ selector = ".ui-scroll-fade", priority = 0, properties = { BorderSizePixel = 0 } },
} :: { Component.Rule }

ScrollArea.fades = { true, false, "content" } :: { any }

-- The nearest ancestor of `object` with a background that shows, up to its gui.
function ScrollArea.surfaceOf(object: Instance): GuiObject?
	local node = object.Parent
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and node.Visible then
			local transparency = node:GetStyled("BackgroundTransparency") :: number
			if transparency < 1 then
				return node
			end
		end
		node = node.Parent
	end
	return nil
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "scroll-area",
	defaults = { visible = true },
	rules = ScrollArea.rules,
	render = function(h)
		local p: Component.Props = h.props
		local key: string = p.direction or "vertical"
		local axis = DIRECTIONS[key]
		if not axis then
			error(`ScrollArea: unknown direction "{key}" (vertical, horizontal or both)`, 0)
		end

		local mode: string = p.scrollbar or "hover"
		if not table.find(ScrollArea.scrollbars, mode) then
			error(`ScrollArea: unknown scrollbar "{mode}" (hover, auto, always, scroll or glimpse)`, 0)
		end
		h.scrollbar = mode
		local fadeMode: any = if p.fade == nil then true else p.fade
		if not table.find(ScrollArea.fades, fadeMode) then
			error(`ScrollArea: unknown fade "{tostring(fadeMode)}" (true, false or "content")`, 0)
		end

		-- What the bar's visibility depends on: overflow, the pointer, and recent scrolling.
		local canvas = Reactive.ref(Vector2.zero)
		local window = Reactive.ref(Vector2.zero)
		local pointer = Reactive.ref(false)
		local recent = Reactive.ref(false)
		local inputMode = h.app.state:ref("input.mode")
		local hideDelay: number = p.hideDelay or 0.6
		local pulses = 0
		local function pulse()
			pulses += 1
			local mine = pulses
			recent(true)
			task.delay(hideDelay, function()
				if pulses == mine then
					recent(false)
				end
			end)
		end
		local function overflows(): boolean
			local c, w = canvas(), window()
			local x, y = c.X > w.X + 1, c.Y > w.Y + 1
			return if key == "vertical" then y elseif key == "horizontal" then x else x or y
		end
		h.overflows = overflows -- for parts outside the area that line up with it (a table header)
		local function barVisible(): boolean
			if mode == "always" then
				return true
			end
			if not overflows() then
				return false
			end
			if mode == "auto" then
				return true
			elseif mode == "hover" then
				local input = inputMode()
				return recent() or (pointer() and input ~= "touch" and input ~= "gamepad")
			end
			return recent() -- scroll, glimpse
		end
		-- The mouse entering or leaving (also how specs simulate it).
		h._pointer = function(on: boolean)
			pointer(on)
			if on and mode == "glimpse" then
				pulse()
			end
		end

		local paddingChild: UIPadding? = nil
		if p.padding ~= nil then
			local pad = Component.space(h.app, p.padding, 0)
			paddingChild = Element.new("UIPadding", {
				PaddingTop = pad,
				PaddingBottom = pad,
				PaddingLeft = pad,
				PaddingRight = pad,
			})
		end

		local maxHeight = p.maxHeight
		local measured: Reactive.Ref<Vector2> = Reactive.ref(Vector2.zero)

		-- A vertical area's content is as wide as the window, which narrows by the
		-- bar's width once it scrolls, so nothing runs under the scrollbar.
		local content: Frame
		local contentSize: any = axis.content
		if key == "vertical" then
			contentSize = function(): UDim2
				local width = window().X
				if width <= 0 or not content then
					return axis.content
				end
				return UDim2.fromOffset(width / Scroll.scaleOf(content), 0)
			end
		end

		content = Element.new("Frame", {
			Name = "Content",
			Size = contentSize,
			AutomaticSize = axis.automatic,
			Tags = { "ui-scroll-area-content" },
			[OUT_SIZE] = measured :: any,
			paddingChild :: any,
		})
		Component.adopt(content, p.children)
		h.content = content

		-- Whether anything inside can take gamepad selection; followed as children
		-- come and go (looked at once things settle, as removals fire before).
		local hasSelectable = Reactive.ref(false)
		local function recount()
			for _, descendant in content:GetDescendants() do
				if descendant:IsA("GuiObject") and descendant.Selectable then
					hasSelectable(true)
					return
				end
			end
			hasSelectable(false)
		end
		recount()
		local function later()
			task.defer(function()
				if not h.destroyed then
					recount()
				end
			end)
		end
		local added = content.DescendantAdded:Connect(later)
		local removing = content.DescendantRemoving:Connect(later)
		Reactive.onCleanup(function()
			added:Disconnect()
			removing:Disconnect()
		end)

		local given: UDim2? = p.size
		local size: any = given or UDim2.fromScale(1, 1)
		if maxHeight ~= nil then
			-- A ScrollingFrame with AutomaticSize ignores a UISizeConstraint, and its
			-- canvas is never smaller than itself, so measure the content frame.
			local width = if given then given.X else UDim.new(1, 0)
			size = function(): UDim2
				local height = measured().Y / Scroll.scaleOf(content)
				local cap: number = Reactive.toValue(maxHeight)
				return UDim2.new(width.Scale, width.Offset, 0, math.min(math.ceil(height), cap))
			end
		end

		-- Edge fades: children of the ScrollingFrame moved with the canvas, so they
		-- stay on the window's edges, each shown while there is more past it.
		local position = Reactive.ref(Vector2.zero)
		local fades: { [string]: Frame } = {}
		h.fades = fades
		if fadeMode == true then
			local reach = ScrollArea.fadeSize
			local function scale(): number
				return Scroll.scaleOf(content)
			end
			local function edge(
				side: string,
				rotation: number,
				frame: () -> UDim2,
				at: () -> UDim2,
				shown: () -> boolean
			)
				fades[side] = Element.new("Frame", {
					Name = `Fade{side}`,
					ZIndex = 2,
					Active = false,
					Interactable = false,
					Selectable = false,
					Size = frame,
					Position = at,
					Visible = shown,
					Tags = { "ui-scroll-fade" },
					Element.new("UIGradient", {
						Rotation = rotation,
						Transparency = NumberSequence.new(0, 1),
					}),
				})
			end
			if key ~= "horizontal" then
				local function across(): UDim2
					return UDim2.fromOffset(window().X / scale(), reach)
				end
				edge("top", 90, across, function()
					local s = scale()
					return UDim2.fromOffset(position().X / s, position().Y / s)
				end, function()
					return position().Y > 0.5
				end)
				edge("bottom", 270, across, function()
					local s = scale()
					return UDim2.fromOffset(position().X / s, (position().Y + window().Y) / s - reach)
				end, function()
					return position().Y + window().Y < canvas().Y - 0.5
				end)
			end
			if key ~= "vertical" then
				local function down(): UDim2
					return UDim2.fromOffset(reach, window().Y / scale())
				end
				edge("left", 0, down, function()
					local s = scale()
					return UDim2.fromOffset(position().X / s, position().Y / s)
				end, function()
					return position().X > 0.5
				end)
				edge("right", 180, down, function()
					local s = scale()
					return UDim2.fromOffset((position().X + window().X) / s - reach, position().Y / s)
				end, function()
					return position().X + window().X < canvas().X - 0.5
				end)
			end
		end

		local holder = Element.new("Frame", {
			Name = "Holder",
			Size = axis.holder,
			BackgroundTransparency = 1,
			Active = false,
			Selectable = false,
			content,
		})
		local grouped = fadeMode == "content"
		local frame = Element.new("ScrollingFrame", {
			Size = if grouped then UDim2.fromScale(1, 1) else size,
			CanvasSize = function(): UDim2
				local m, s = measured(), Scroll.scaleOf(content)
				return UDim2.fromOffset(if axis.x then m.X / s else 0, if axis.y then m.Y / s else 0)
			end,
			AutomaticCanvasSize = Enum.AutomaticSize.None,
			ScrollingDirection = axis.scrolling,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			Selectable = function(): boolean
				return not hasSelectable() and overflows()
			end,
			Visible = if grouped then true else h:ref("visible"),
			Tags = { "ui-scroll-area" :: any, ["ui-scroll-bar-visible"] = barVisible },
			[OUT_CANVAS] = canvas :: any,
			[OUT_WINDOW] = window :: any,
			[OUT_POSITION] = position :: any,
			[ON_SCROLL] = function()
				if mode ~= "auto" and mode ~= "always" then
					pulse()
				end
			end,
			[ON_ENTER] = function()
				h._pointer(true)
			end,
			[ON_LEAVE] = function()
				h._pointer(false)
			end,
			holder,
		})
		for _, fade in fades do
			fade.Parent = frame
		end
		h.frame = frame

		-- Colour fades follow the surface they sit on: its styled colour and
		-- transparency, read again whenever an ancestor's look or the ancestry changes.
		if next(fades) then
			local fallback = h.app.theme:resolve("Background")
			local watching: { RBXScriptConnection } = {}
			local function apply()
				local surface = ScrollArea.surfaceOf(frame)
				local color: Color3 = if surface then surface:GetStyled("BackgroundColor3") else fallback
				local transparency: number = if surface
					then surface:GetStyled("BackgroundTransparency")
					else 0
				for _, fade in fades do
					fade.BackgroundColor3 = color
					fade.BackgroundTransparency = transparency
				end
			end
			local function rewatch()
				for _, connection in watching do
					connection:Disconnect()
				end
				table.clear(watching)
				local node = frame.Parent
				while node and not node:IsA("LayerCollector") do
					if node:IsA("GuiObject") then
						table.insert(watching, node.StyledPropertiesChanged:Connect(apply))
						table.insert(
							watching,
							node:GetPropertyChangedSignal("BackgroundColor3"):Connect(apply)
						)
						table.insert(
							watching,
							node:GetPropertyChangedSignal("BackgroundTransparency"):Connect(apply)
						)
						table.insert(watching, node:GetPropertyChangedSignal("Visible"):Connect(apply))
					end
					node = node.Parent
				end
				apply()
			end
			local moved = frame.AncestryChanged:Connect(rewatch)
			rewatch()
			Reactive.onCleanup(function()
				moved:Disconnect()
				for _, connection in watching do
					connection:Disconnect()
				end
			end)
		end

		if not grouped then
			return frame
		end

		-- fade = "content": the window in a CanvasGroup whose gradient fades the
		-- ends with more to scroll past.
		local vertical = key ~= "horizontal"
		local function sequence(): NumberSequence
			local w, c, at = window(), canvas(), position()
			local length = if vertical then w.Y else w.X
			if length <= 0 then
				return NumberSequence.new(0)
			end
			local reach = math.min(ScrollArea.fadeSize * Scroll.scaleOf(content) / length, 0.45)
			local before = if vertical then at.Y > 0.5 else at.X > 0.5
			local after = if vertical then at.Y + w.Y < c.Y - 0.5 else at.X + w.X < c.X - 0.5
			local points = { NumberSequenceKeypoint.new(0, if before then 1 else 0) }
			if before then
				table.insert(points, NumberSequenceKeypoint.new(reach, 0))
			end
			if after then
				table.insert(points, NumberSequenceKeypoint.new(1 - reach, 0))
			end
			table.insert(points, NumberSequenceKeypoint.new(1, if after then 1 else 0))
			return NumberSequence.new(points)
		end
		return Element.new("CanvasGroup", {
			Size = size,
			BackgroundTransparency = 1,
			Visible = h:ref("visible"),
			Tags = { "ui-scroll-group" },
			Element.new("UIGradient", {
				Rotation = if vertical then 90 else 0,
				Transparency = sequence,
			}),
			frame,
		})
	end,
}

function ScrollArea.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return ScrollArea
