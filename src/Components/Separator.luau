--!strict
--[[
	Separator

		Separator.new({ orientation = "horizontal" }) -- horizontal | vertical

	State keys: orientation, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)

local Separator = {}

local rules: { Component.Rule } = {
	{
		selector = ".ui-separator",
		priority = 0,
		properties = { BackgroundColor3 = "$Border", BorderSizePixel = 0 },
	},
}
Separator.rules = rules

function Separator.new(props: { [string]: any }?)
	return Component.mount({
		kind = "separator",
		props = props,
		defaults = { orientation = "horizontal", visible = true },
		rules = Separator.rules,
		render = function()
			return Component.create("Frame", { Tags = { "ui-separator" } })
		end,
		update = function(h, state)
			local vertical = state.orientation == "vertical"
			h.Instance.Size = if vertical then UDim2.new(0, 1, 1, 0) else UDim2.new(1, 0, 0, 1)
			h.Instance.Visible = state.visible
			Component.setVariant(h.Instance, "ui-separator", "orientation", state.orientation)
		end,
	})
end

return Separator
