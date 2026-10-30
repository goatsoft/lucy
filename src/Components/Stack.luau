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

function Stack.new(props: { [string]: any }?)
	local p = props or {}
	return Component.mount({
		kind = "stack",
		props = p,
		defaults = { visible = true },
		render = function(h)
			local frame = Component.box({})
			local layout = Component.list({ Wraps = p.wrap == true })
			layout.Parent = frame
			h.layout = layout

			local function layoutNow()
				local app = h.app
				local horizontal = Responsive.pick(app, p.direction) == "horizontal"
				local align = Responsive.pick(app, p.align) or "start"
				local justify = Responsive.pick(app, p.justify) or "start"
				layout.FillDirection = if horizontal
					then Enum.FillDirection.Horizontal
					else Enum.FillDirection.Vertical
				layout.Padding = Component.space(app, Responsive.pick(app, p.gap), 0)
				layout.HorizontalFlex = Enum.UIFlexAlignment.None
				layout.VerticalFlex = Enum.UIFlexAlignment.None
				if horizontal then
					layout.VerticalAlignment = V[align] or V.start
					if justify == "between" then
						layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
					else
						layout.HorizontalAlignment = H[justify] or H.start
					end
				else
					layout.HorizontalAlignment = H[align] or H.start
					if justify == "between" then
						layout.VerticalFlex = Enum.UIFlexAlignment.SpaceBetween
					else
						layout.VerticalAlignment = V[justify] or V.start
					end
				end
				local size = Responsive.pick(app, p.size)
				frame.Size = size or (if horizontal then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0))
				frame.AutomaticSize = p.automaticSize
					or (
						if size
							then Enum.AutomaticSize.None
							elseif horizontal then Enum.AutomaticSize.XY
							else Enum.AutomaticSize.Y
					)

				local padding = Responsive.pick(app, p.padding)
				local pad = frame:FindFirstChild("StackPadding") :: UIPadding?
				if padding ~= nil then
					if not pad then
						pad = Component.create("UIPadding", { Name = "StackPadding", Parent = frame })
					end
					local value = Component.space(app, padding, 0)
					pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight =
						value, value, value, value
				elseif pad then
					pad:Destroy()
				end
			end
			layoutNow()

			-- Re-layout when the device, input mode or breakpoint changes.
			local responsive = false
			for _, key in { "direction", "gap", "align", "justify", "padding", "size" } do
				if Responsive.isResponsive(p[key]) then
					responsive = true
				end
			end
			if responsive then
				h.maid:give(h.app.state:subscribe("input", layoutNow))
			end

			Component.adopt(frame, p.children)
			return frame
		end,
		update = function(h, state)
			h.Instance.Visible = state.visible
		end,
	})
end

return Stack
