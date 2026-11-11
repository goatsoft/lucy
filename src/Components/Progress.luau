--!strict
--[[
	Progress

		local bar = Progress.new({ id = "reload", value = 30, max = 100 })
		app.state:set("ui.reload.value", 75)

		variant = "default"   -- default | success | warning | destructive (the bar's colour)

	State keys: value, max, variant, visible. The value is clamped to 0..max.

	Stepped: with `steps = n` the bar becomes a rail of n numbered markers (a battle pass's tiers,
	a quest's stages). `value` is then in steps: the fill reaches marker i's centre at value i, and
	a marker is lit once the value reaches it. `max` is not used. `stepSize` is a marker's size in
	pixels (28). Markers are evenly spaced, marker i centred at (i - 0.5) / n of the width, so a
	row of n equal columns above or below lines up with them.

		Progress.new({ steps = 100, value = function() return tier() + xp() / perTier end, height = 10 })
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
-- Stepped (steps = n): numbered markers over the bar, lit up to the value
table.insert(rules, {
	selector = ".ui-progress-step",
	priority = 0,
	properties = {
		BackgroundColor3 = "$Secondary",
		TextColor3 = "$SecondaryForeground",
		FontFace = "$FontSansSemibold",
		TextSize = "$TextSm",
		BorderSizePixel = 0,
	},
})
table.insert(
	rules,
	{ selector = ".ui-progress-step::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } }
)
table.insert(rules, {
	selector = ".ui-progress-step-on",
	priority = 5,
	properties = { BackgroundColor3 = "$Primary", TextColor3 = "$PrimaryForeground" },
})
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

-- Stepped: how full the bar is for a value in steps. The fill reaches marker i's centre at
-- value i; before the first marker it grows toward it.
function Progress.stepFraction(value: number, steps: number): number
	if steps <= 0 or value <= 0 then
		return 0
	end
	if value < 1 then
		return value * 0.5 / steps
	end
	return math.clamp((value - 0.5) / steps, 0, 1)
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
		local function variantTagNow(): string
			local v = variant()
			checkVariant(v)
			return variantTag[v]
		end
		if type(p.steps) == "number" and p.steps >= 1 then
			local steps = math.floor(p.steps)
			local stepSize = p.stepSize or 28
			h.indicator = Element.new("Frame", {
				Name = "Indicator",
				Size = function()
					return UDim2.fromScale(Progress.stepFraction(value(), steps), 1)
				end,
				Tags = { "ui-progress-indicator" },
			})
			local children: { any } = {
				Element.new("Frame", {
					Name = "Bar",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.new(1, 0, 0, p.height or 8),
					ClipsDescendants = true,
					Tags = { "ui-progress" :: any, variantTagNow },
					h.indicator,
				}),
			}
			h.steps = {}
			for i = 1, steps do
				local marker = Element.new("TextLabel", {
					Name = `Step{i}`,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale((i - 0.5) / steps, 0.5),
					Size = UDim2.fromOffset(stepSize, stepSize),
					Text = tostring(i),
					ZIndex = 2,
					Tags = {
						"ui-progress-step" :: any,
						function(): string?
							return if value() >= i then "ui-progress-step-on" else nil
						end,
					},
				})
				h.steps[i] = marker
				table.insert(children, marker)
			end
			return Element.new("Frame", {
				Size = UDim2.new(1, 0, 0, math.max(stepSize, p.height or 8)),
				BackgroundTransparency = 1,
				Visible = h:ref("visible"),
				Tags = { "ui-progress-stepped" },
				children,
			})
		end
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
