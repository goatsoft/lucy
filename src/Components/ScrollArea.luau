--!strict
--[[
	ScrollArea: a region that scrolls when its content does not fit.

		ScrollArea.new({
			direction = "vertical",   -- vertical | horizontal | both
			size = UDim2,             -- fills the parent when left out
			maxHeight = 300,          -- optional: fit the content up to this height, then scroll
			padding = "Space4",       -- optional: a spacing token, pixels or a UDim
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
	InputManager (Core/Scroll).

	State keys: visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)

local ScrollArea = {}

local OUT_SIZE = Element.out("AbsoluteSize")

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
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
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

		local content = Element.new("Frame", {
			Name = "Content",
			Size = axis.content,
			AutomaticSize = axis.automatic,
			Tags = { "ui-scroll-area-content" },
			[OUT_SIZE] = measured :: any,
			paddingChild :: any,
		})
		Component.adopt(content, p.children)
		h.content = content

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
			Selectable = false,
			Visible = h:ref("visible"),
			Tags = { "ui-scroll-area" },
			content,
		})
	end,
}

function ScrollArea.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return ScrollArea
