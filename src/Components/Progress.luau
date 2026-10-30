--!strict
--[[
	Progress

		local bar = Progress.new({ id = "reload", value = 30, max = 100 })
		app.state:set("ui.reload.value", 75)

	State keys: value, max, visible. The value is clamped to 0..max.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Progress = {}

local rules: { Component.Rule } = {
	{
		selector = ".ui-progress",
		priority = 0,
		properties = { BackgroundColor3 = "$Secondary", BorderSizePixel = 0 },
	},
	{ selector = ".ui-progress::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-progress-indicator",
		priority = 0,
		properties = { BackgroundColor3 = "$Primary", BorderSizePixel = 0 },
	},
	{
		selector = ".ui-progress-indicator::UICorner",
		priority = 0,
		properties = { CornerRadius = "$RadiusFull" },
	},
}
Progress.rules = rules

function Progress.fraction(value: number, max: number): number
	if max <= 0 then
		return 0
	end
	return math.clamp(value / max, 0, 1)
end

function Progress.new(props: { [string]: any }?)
	local p: Component.Props = props or {}
	return Component.mount({
		kind = "progress",
		props = p,
		defaults = { value = 0, max = 100, visible = true },
		rules = Progress.rules,
		render = function(h)
			local value, max = h:ref("value"), h:ref("max")
			h.indicator = Element.new("Frame", {
				Name = "Indicator",
				Size = function()
					return UDim2.fromScale(Progress.fraction(value(), max()), 1)
				end,
				Tags = { "ui-progress-indicator" },
			})
			return Element.new("Frame", {
				Size = UDim2.new(1, 0, 0, p.height or 8),
				ClipsDescendants = true,
				Visible = h:ref("visible"),
				Tags = { "ui-progress" },
				h.indicator,
			})
		end,
	})
end

return Progress
