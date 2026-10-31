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
			children = { ... },       -- instances, handles or functions
			visible = true,
			Parent = frame,
		})

	handle.Instance is the ScrollingFrame; handle.content is the frame inside it
	that holds the children. It lays out nothing itself: put a Stack inside to
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

	State keys: visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)

local ScrollArea = {}

local OUT_SIZE = Element.out("AbsoluteSize")
local OUT_CANVAS = Element.out("AbsoluteCanvasSize")
local OUT_WINDOW = Element.out("AbsoluteWindowSize")
local ON_SCROLL = Element.changed("CanvasPosition")
local ON_ENTER = Element.on("MouseEnter")
local ON_LEAVE = Element.on("MouseLeave")

ScrollArea.scrollbars = { "hover", "auto", "always", "scroll", "glimpse" }

type Axis = {
	scrolling: Enum.ScrollingDirection,
	automatic: Enum.AutomaticSize,
	content: UDim2,
}

local DIRECTIONS: { [string]: Axis } = {
	vertical = {
		scrolling = Enum.ScrollingDirection.Y,
		automatic = Enum.AutomaticSize.Y,
		content = UDim2.fromScale(1, 0),
	},
	horizontal = {
		scrolling = Enum.ScrollingDirection.X,
		automatic = Enum.AutomaticSize.X,
		content = UDim2.fromScale(0, 1),
	},
	both = {
		scrolling = Enum.ScrollingDirection.XY,
		automatic = Enum.AutomaticSize.XY,
		content = UDim2.fromScale(0, 0),
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
} :: { Component.Rule }

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
		local measured: Reactive.Ref<Vector2>? = if maxHeight ~= nil then Reactive.ref(Vector2.zero) else nil

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
		if measured then
			-- A ScrollingFrame with AutomaticSize ignores a UISizeConstraint, and its
			-- canvas is never smaller than itself, so measure the content frame.
			local width = if given then given.X else UDim.new(1, 0)
			size = function(): UDim2
				local height = measured().Y / Scroll.scaleOf(content)
				local cap: number = Reactive.toValue(maxHeight)
				return UDim2.new(width.Scale, width.Offset, 0, math.min(math.ceil(height), cap))
			end
		end

		return Element.new("ScrollingFrame", {
			Size = size,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = axis.automatic,
			ScrollingDirection = axis.scrolling,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			Selectable = function(): boolean
				return not hasSelectable() and overflows()
			end,
			Visible = h:ref("visible"),
			Tags = { "ui-scroll-area" :: any, ["ui-scroll-bar-visible"] = barVisible },
			[OUT_CANVAS] = canvas :: any,
			[OUT_WINDOW] = window :: any,
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
			content,
		})
	end,
}

function ScrollArea.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return ScrollArea
