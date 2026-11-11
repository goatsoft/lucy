--!strict
--[[
	Effect type "outline" (Components/Effect): light that follows the shape of what it is behind,
	a button, a card, a plate. A soft glow round the whole edge, a steady rim, and a bright
	stretch of light that runs round and round the rim. It fades in, then keeps running, and the
	glow breathes a little.

		local button = Lucy.Button.new({ text = "UNLOCK", Parent = row })
		Lucy.Effect.new({ type = "outline", variant = "warning", radius = 8, Parent = button.Instance })

	The effect fills its box (it is not kept square), so give it the box of the thing it lights,
	or parent it to that thing. The light is drawn outside the box's edge.

	Options: radius (the corner radius in pixels, to match the thing it lights; default 8),
	thickness (the rim, in pixels; default 2), speed (degrees a second the light runs; 0: no
	running light; default 140), glow (the soft glow round the edge; default true), pulse (the
	glow breathes; default true).

	Parts on the handle: glow, rim and light (the three frames), sweep (the UIGradient that
	turns). Tags: ui-effect-outline-glow, ui-effect-outline-rim, ui-effect-outline-light, and on
	each ui-effect-outline-<variant>.
]]

local Component = require(script.Parent.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Parent.Core.Element)

local FADE = 0.35 -- seconds to fade in
local BREATH_SECONDS = 2.4
local GLOW_WIDTH = 3 -- the glow, in rim thicknesses
local GLOW_TRANSPARENCY = 0.72
local RIM_TRANSPARENCY = 0.45

-- The running light: clear all the way round but for one bright stretch
local SWEEP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.7, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local rules: { Component.Rule } = {
	{ selector = ".ui-effect-outline-part", priority = 0, properties = { BackgroundTransparency = 1 } },
	{ selector = ".ui-effect-outline-part::UIStroke", priority = 0, properties = { Color = "$Primary" } },
	{ selector = ".ui-effect-outline-warning::UIStroke", priority = 10, properties = { Color = "$Warning" } },
	{ selector = ".ui-effect-outline-success::UIStroke", priority = 10, properties = { Color = "$Success" } },
	{
		selector = ".ui-effect-outline-foreground::UIStroke",
		priority = 10,
		properties = { Color = "$Foreground" },
	},
	-- The running light is white hot
	{ selector = ".ui-effect-outline-light::UIStroke", priority = 20, properties = { Color = "$White" } },
}

return {
	intro = FADE,
	loop = true,
	fill = true, -- the picture takes the whole box, whatever its shape
	defaults = { radius = 8, thickness = 2, speed = 140, glow = true, pulse = true },
	rules = rules,
	render = function(ctx: any): Instance
		local radius = math.max(0, tonumber(ctx.option("radius")) or 8)
		local thickness = math.max(1, tonumber(ctx.option("thickness")) or 2)
		local speed = tonumber(ctx.option("speed")) or 0
		local pulsing = ctx.option("pulse") ~= false

		-- 0 to 1 as it fades in
		local function shown(): number
			return math.clamp(ctx.intro() / FADE, 0, 1)
		end
		local function breath(): number
			return if pulsing then math.sin(ctx.elapsed() / BREATH_SECONDS * 2 * math.pi) else 0
		end
		local function variantTag(): string
			return "ui-effect-outline-" .. ctx.variant()
		end

		-- One frame the size of the box, with a stroke round it
		local function part(name: string, tag: string, stroke: { [any]: any }): Instance
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			return Element.new("Frame", {
				Name = name,
				Size = UDim2.fromScale(1, 1),
				Tags = { "ui-effect-outline-part" :: any, tag, variantTag },
				Element.new("UICorner", { CornerRadius = UDim.new(0, radius) }),
				Element.new("UIStroke", stroke),
			})
		end

		local children: { any } = {}
		if ctx.option("glow") ~= false then
			local glow = part("Glow", "ui-effect-outline-glow", {
				Thickness = function(): number
					return thickness * GLOW_WIDTH * (1 + 0.25 * breath())
				end,
				Transparency = function(): number
					return 1 - (1 - GLOW_TRANSPARENCY) * shown()
				end,
			})
			ctx.handle.glow = glow
			table.insert(children, glow)
		end
		local rim = part("Rim", "ui-effect-outline-rim", {
			Thickness = thickness,
			Transparency = function(): number
				return 1 - (1 - RIM_TRANSPARENCY) * shown()
			end,
		})
		ctx.handle.rim = rim
		table.insert(children, rim)
		if speed ~= 0 then
			local sweep = Element.new("UIGradient", {
				Transparency = SWEEP,
				Rotation = function(): number
					return (ctx.elapsed() * speed) % 360
				end,
			})
			local light = part("Light", "ui-effect-outline-light", {
				Thickness = thickness,
				Transparency = function(): number
					return 1 - shown()
				end,
				sweep,
			})
			ctx.handle.light = light
			ctx.handle.sweep = sweep
			table.insert(children, light)
		end

		return Element.new("Frame", {
			Name = "Outline",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			children,
		})
	end,
}
