--!strict
--[[
	Effect type "rays" (Components/Effect): a sunburst of light rays that fan out from the middle
	one after another, then slowly turn. Every other ray is fainter; each fades in from the middle
	(no blob at the centre) and out to its tip.

		Lucy.Effect.new({ type = "rays", count = 12, spin = 18, width = 0.06, Parent = frame })

	Options: count (rays round the circle), spin (degrees a second, 0: still), width (each ray's
	width as a share of the burst). Parts on the handle: rays, arms (each turned to its ray's
	angle), wheel (turns them all). Tags: ui-effect-rays-ray, ui-effect-rays-ray-alt,
	ui-effect-rays-ray-<variant>.
]]

local Component = require(script.Parent.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Parent.Core.Element)

local FAN_SECONDS = 0.5 -- each ray, from the middle to full length
local FAN_STAGGER = 0.3 -- the last ray starts this long after the first
local LENGTH = 0.5 -- of the burst: centre to edge

local FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.45, 0.2),
	NumberSequenceKeypoint.new(0.85, 0.55),
	NumberSequenceKeypoint.new(1, 1),
})

local rules: { Component.Rule } = {
	{
		selector = ".ui-effect-rays-ray",
		priority = 0,
		properties = { BackgroundColor3 = "$Primary", BackgroundTransparency = 0, BorderSizePixel = 0 },
	},
	{ selector = ".ui-effect-rays-ray-alt", priority = 5, properties = { BackgroundTransparency = 0.45 } },
	{
		selector = ".ui-effect-rays-ray-warning",
		priority = 10,
		properties = { BackgroundColor3 = "$Warning" },
	},
	{
		selector = ".ui-effect-rays-ray-success",
		priority = 10,
		properties = { BackgroundColor3 = "$Success" },
	},
	{
		selector = ".ui-effect-rays-ray-foreground",
		priority = 10,
		properties = { BackgroundColor3 = "$Foreground" },
	},
}

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

return {
	intro = FAN_STAGGER + FAN_SECONDS,
	loop = true,
	defaults = { count = 12, spin = 18, width = 0.06 },
	rules = rules,
	render = function(ctx: any): Instance
		local count = math.max(1, math.floor(tonumber(ctx.option("count")) or 12))
		local spin = tonumber(ctx.option("spin")) or 0
		local width = tonumber(ctx.option("width")) or 0.06

		local rays, arms = {}, {}
		for i = 1, count do
			local delay = (i - 1) / math.max(count - 1, 1) * FAN_STAGGER
			local tags: { any } = {
				"ui-effect-rays-ray",
				function()
					return "ui-effect-rays-ray-" .. ctx.variant()
				end,
			}
			if i % 2 == 0 then
				table.insert(tags, "ui-effect-rays-ray-alt")
			end
			local ray = Element.new("Frame", {
				Name = "Ray",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = function()
					return UDim2.fromScale(width, LENGTH * easeOut((ctx.intro() - delay) / FAN_SECONDS))
				end,
				Tags = tags,
				Element.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Element.new("UIGradient", { Rotation = 90, Transparency = FADE }),
			})
			local arm = Element.new("Frame", {
				Name = "Arm",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Rotation = (i - 1) * 360 / count,
				ray,
			})
			table.insert(rays, ray)
			table.insert(arms, arm)
		end

		local wheel = Element.new("Frame", {
			Name = "Wheel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Rotation = function()
				return (ctx.elapsed() * spin) % 360
			end,
			table.unpack(arms),
		})
		ctx.handle.rays = rays
		ctx.handle.arms = arms
		ctx.handle.wheel = wheel
		return wheel
	end,
}
