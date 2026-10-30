--!strict
--[[
	Stack: a flex row or column.

		Stack.new({
			direction = "vertical",   -- vertical | horizontal
			gap = "Space4",           -- spacing token name, pixels or a UDim
			align = "start",          -- cross axis: start | center | end
			justify = "start",        -- main axis: start | center | end | between
			padding = "Space4",       -- optional, same forms as gap
			wrap = false,
			size = UDim2,             -- optional; defaults to filling width (column) or hugging (row)
			children = { ... },       -- instances, handles or functions
		})

	direction, gap, align, justify and padding also take responsive values:
		direction = { mobile = "vertical", default = "horizontal" }
		gap = { console = "Space6", touch = "Space4", default = "Space2" }

	handle.Instance is the container; parent more children into it any time.
	State keys: visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
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
}
local RESPONSIVE_KEYS = { "direction", "gap", "align", "justify", "padding", "size" }

function Stack.new(props: { [string]: any }?)
	local p: Component.Props = props or {}
	return Component.mount({
		kind = "stack",
		props = p,
		defaults = { visible = true },
		render = function(h)
			local app = h.app
			local responsive = false
			for _, key in RESPONSIVE_KEYS do
				if Responsive.isResponsive(p[key]) then
					responsive = true
				end
			end
			local direction = Composables.useResponsive(app, p.direction)
			local gap = Composables.useResponsive(app, p.gap)
			local align = Composables.useResponsive(app, p.align)
			local justify = Composables.useResponsive(app, p.justify)
			local padding = Composables.useResponsive(app, p.padding)
			local size = Composables.useResponsive(app, p.size)
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
					return if horizontal() and between()
						then Enum.UIFlexAlignment.SpaceBetween
						else Enum.UIFlexAlignment.None
				end),
				VerticalFlex = layout(function()
					return if not horizontal() and between()
						then Enum.UIFlexAlignment.SpaceBetween
						else Enum.UIFlexAlignment.None
				end),
				-- Cross axis follows align, main axis follows justify ("between" is a flex).
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
					return p.automaticSize
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
			return frame
		end,
	})
end

return Stack
