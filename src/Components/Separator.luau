--!strict
--[[
	Separator

		Separator.new({ orientation = "horizontal" }) -- horizontal | vertical

	State keys: orientation, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

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
		render = function(h)
			local orientation = h:ref("orientation")
			return Element.new("Frame", {
				Size = function()
					return if orientation() == "vertical"
						then UDim2.new(0, 1, 1, 0)
						else UDim2.new(1, 0, 0, 1)
				end,
				Visible = h:ref("visible"),
				Tags = {
					"ui-separator" :: any,
					function()
						return "ui-separator-orientation-" .. orientation()
					end,
				},
			})
		end,
	})
end

return Separator
