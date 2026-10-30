--[[
	Progress

		local bar = Progress.new({ id = "reload", value = 30, max = 100 })
		app.state:set("ui.reload.value", 75)

	State keys: value, max, visible. The value is clamped to 0..max.
]]

local Component = require(script.Parent.Parent.Core.Component)

local Progress = {}

Progress.rules = {
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

function Progress.fraction(value: number, max: number): number
	if max <= 0 then
		return 0
	end
	return math.clamp(value / max, 0, 1)
end

function Progress.new(props: { [string]: any }?)
	local p = props or {}
	return Component.mount({
		kind = "progress",
		props = p,
		defaults = { value = 0, max = 100, visible = true },
		rules = Progress.rules,
		render = function(h)
			local track = Component.create("Frame", {
				Size = UDim2.new(1, 0, 0, p.height or 8),
				ClipsDescendants = true,
				Tags = { "ui-progress" },
			})
			h.indicator = Component.create("Frame", {
				Name = "Indicator",
				Size = UDim2.fromScale(0, 1),
				Tags = { "ui-progress-indicator" },
				Parent = track,
			})
			return track
		end,
		update = function(h, state)
			h.Instance.Visible = state.visible
			h.indicator.Size = UDim2.fromScale(Progress.fraction(state.value, state.max), 1)
		end,
	})
end

return Progress
