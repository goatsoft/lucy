--!strict
--[[
	Progress

		local bar = Progress.new({ id = "reload", value = 30, max = 100 })
		app.state:set("ui.reload.value", 75)

		variant = "default"   -- default | success | warning | destructive (the bar's colour)

	State keys: value, max, variant, visible. The value is clamped to 0..max.
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
Progress.variants = { "default", "success", "warning", "destructive" }
local COLOURS = { success = "$Success", warning = "$Warning", destructive = "$Destructive" }
for variant, colour in COLOURS do
	table.insert(rules, {
		selector = `.ui-progress-variant-{variant} > .ui-progress-indicator`,
		priority = 10,
		properties = { BackgroundColor3 = colour },
	})
end
Progress.rules = rules

local function checkVariant(variant: string)
	if not table.find(Progress.variants, variant) then
		error(
			`[Lucy] unknown Progress variant "{variant}" (expected {table.concat(Progress.variants, ", ")})`,
			0
		)
	end
end

-- One tag per variant, built once.
local variantTag: { [string]: string } = {}
for _, variant in Progress.variants do
	variantTag[variant] = "ui-progress-variant-" .. variant
end

function Progress.fraction(value: number, max: number): number
	if max <= 0 then
		return 0
	end
	return math.clamp(value / max, 0, 1)
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "progress",
	defaults = { value = 0, max = 100, variant = "default", visible = true },
	rules = Progress.rules,
	render = function(h)
		local p: Component.Props = h.props
		-- An unknown variant fails the mount; later writes report like any effect.
		checkVariant(h:get("variant"))
		local value, max, variant = h:ref("value"), h:ref("max"), h:ref("variant")
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
			Tags = {
				"ui-progress" :: any,
				function(): string
					local v = variant()
					checkVariant(v)
					return variantTag[v]
				end,
			},
			h.indicator,
		})
	end,
}

function Progress.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Progress
