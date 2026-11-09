--!strict
--[[
	Stack: a flex row or column.

		Stack.new({
			direction = "vertical",   -- vertical | horizontal
			gap = "Space4",           -- spacing token name, pixels or a UDim
			align = "start",          -- cross axis: start | center | end | stretch (children fill it)
			                          -- | baseline (a row: its texts on one baseline, see Core/Baseline)
			justify = "start",        -- main axis: start | center | end | between
			padding = "Space4",       -- optional, same forms as gap
			wrap = false,
			size = UDim2,             -- optional; defaults to filling width (column) or hugging (row)
			children = { ... },       -- instances, handles or functions
		})

	direction, gap, align, justify, padding, size and automaticSize also take responsive values
	(or a getter, for a layout that follows game state):
		direction = { mobile = "vertical", default = "horizontal" }
		gap = { console = "Space6", touch = "Space4", default = "Space2" }

	Stack.grow(child, when?) lets a child take the room left (see below).

	handle.Instance is the container; parent more children into it any time.
	State keys: visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Baseline = require(script.Parent.Parent.Core.Baseline)
local Element = require(script.Parent.Parent.Core.Element)
local Responsive = require(script.Parent.Parent.Core.Responsive)

local Stack = {}

local H = {
	start = Enum.HorizontalAlignment.Left,
	center = Enum.HorizontalAlignment.Center,
	["end"] = Enum.HorizontalAlignment.Right,
}
local V = {
	start = Enum.VerticalAlignment.Top,
	center = Enum.VerticalAlignment.Center,
	["end"] = Enum.VerticalAlignment.Bottom,
	-- Bottoms aligned, then each text lifted onto the biggest one's baseline (Core/Baseline)
	baseline = Enum.VerticalAlignment.Bottom,
}
local RESPONSIVE_KEYS = { "direction", "gap", "align", "justify", "padding", "size", "automaticSize" }

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "stack",
	defaults = { visible = true },
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local responsive = false
		for _, key in RESPONSIVE_KEYS do
			-- A responsive table or a getter: either can change after the build
			if Responsive.isResponsive(p[key]) or type(p[key]) == "function" then
				responsive = true
			end
		end
		local direction = Composables.useResponsive(app, p.direction)
		local gap = Composables.useResponsive(app, p.gap)
		local align = Composables.useResponsive(app, p.align)
		local justify = Composables.useResponsive(app, p.justify)
		local padding = Composables.useResponsive(app, p.padding)
		local size = Composables.useResponsive(app, p.size)
		local automaticSize = Composables.useResponsive(app, p.automaticSize)
		-- A layout value: bound when anything is responsive, otherwise resolved once.
		local function layout(fn: () -> any): any
			return if responsive then fn else fn()
		end
		local function horizontal(): boolean
			return direction() == "horizontal"
		end
		local function between(): boolean
			return justify() == "between"
		end
		local function stretch(): boolean
			return align() == "stretch"
		end
		-- A flex for one axis: the main axis takes "between", the cross axis "stretch"
		local function flex(main: boolean): Enum.UIFlexAlignment
			if main then
				return if between() then Enum.UIFlexAlignment.SpaceBetween else Enum.UIFlexAlignment.None
			end
			return if stretch() then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None
		end

		h.layout = Element.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = p.wrap == true,
			FillDirection = layout(function()
				return if horizontal() then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
			end),
			Padding = layout(function()
				return Component.space(app, gap(), 0)
			end),
			HorizontalFlex = layout(function()
				return flex(horizontal())
			end),
			VerticalFlex = layout(function()
				return flex(not horizontal())
			end),
			-- Cross axis follows align, main axis follows justify ("between" and "stretch" are
			-- flexes; a stretched cross axis aligns to the start).
			HorizontalAlignment = layout(function()
				local key = if horizontal() then (if between() then "start" else justify()) else align()
				return H[key or "start"] or H.start
			end),
			VerticalAlignment = layout(function()
				local key = if horizontal() then align() else (if between() then "start" else justify())
				return V[key or "start"] or V.start
			end),
		})

		local function pad(): UDim
			return Component.space(app, padding(), 0)
		end
		local function makePadding(): UIPadding
			local value = layout(pad)
			return Element.new("UIPadding", {
				Name = "StackPadding",
				PaddingTop = value,
				PaddingBottom = value,
				PaddingLeft = value,
				PaddingRight = value,
			})
		end
		local paddingChild: any = nil
		if responsive then
			paddingChild = Element.show(function()
				return padding() ~= nil
			end, makePadding)
		elseif padding() ~= nil then
			paddingChild = makePadding()
		end

		local frame = Element.new("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = layout(function()
				return size() or (if horizontal() then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0))
			end),
			AutomaticSize = layout(function()
				return automaticSize()
					or (
						if size()
							then Enum.AutomaticSize.None
							elseif horizontal() then Enum.AutomaticSize.XY
							else Enum.AutomaticSize.Y
					)
			end),
			Visible = h:ref("visible"),
			h.layout,
			paddingChild,
		})
		Component.adopt(frame, p.children)
		-- Only a stack that can be "baseline" (that value, or one that can change) follows it
		if p.align ~= nil and (p.align == "baseline" or type(p.align) ~= "string") then
			Baseline.follow(frame, function(): boolean
				return align() == "baseline" and horizontal()
			end)
		end
		return frame
	end,
}

function Stack.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

--[[
	Lets a child take the room its stack has left along the stack's direction (the
	preview over a shop's buy button, a list under a header). `when` is a boolean
	or a getter (default always): while it is false the child keeps its own size.
	Give the child a size of 0 on that axis while it grows. Returns the child.

		Stack.grow(preview, function() return small() end)
]]
function Stack.grow(child: any, when: (boolean | () -> boolean)?): any
	local instance: Instance = if typeof(child) == "Instance" then child else child.Instance
	local function on(): boolean
		if type(when) == "function" then
			return when() == true
		end
		return when ~= false
	end
	Element.new("UIFlexItem", {
		Name = "Grow",
		FlexMode = function(): Enum.UIFlexMode
			return if on() then Enum.UIFlexMode.Fill else Enum.UIFlexMode.None
		end,
		Parent = instance,
	})
	return child
end

return Stack
