--!strict
--[[
	Effect type "rays" (Components/Effect): a starburst, as light glints off something shiny:
	brightest at the middle and dimmer the further out. A glow with a hot centre, then layers of
	rays, back to front: long thin faint ones reaching furthest, then fewer, shorter, wider and
	brighter ones, a four point glint at the front. They fan out from the middle one after
	another, then slowly turn, every other layer the other way, and gleam: the burst swells a
	little on a sine wave and each ray flares briefly at its own moment, as on loot.

		Lucy.Effect.new({ type = "rays", count = 12, layers = 3, spin = 18, width = 0.28, Parent = frame })

	Options: count (rays in the back layer), layers (how many), spin (degrees a second, 0:
	still), width (the front layer's rays, as a share of the burst), core (the glow in the
	middle, default true), pulse (the gleam, default true).

	Each ray is the streak texture (Effects/Textures) stretched to its length and width, tinted
	by the variant; the glow is the glow texture.

	Parts on the handle: layers ({ rays, arms, wheel } each, back first), rays (every ray), core
	(the glow, then its hot centre), pulse (the UIScale the burst swells by). Tags: on each ray
	ui-effect-rays-ray, ui-effect-rays-ray-<variant>, ui-effect-rays-layer-<n> (from 1 at the
	back) and ui-effect-rays-front on the front layer (white, the glint); on the glow
	ui-effect-rays-core and the variant's tag, and ui-effect-rays-hot on its centre (white).
]]

local Component = require(script.Parent.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Parent.Core.Element)
local Textures = require(script.Parent.Textures)

local FAN_SECONDS = 0.5 -- each ray, from the middle to full length
local FAN_STAGGER = 0.3 -- the last ray in a layer starts this long after its first
local LAYER_STAGGER = 0.2 -- the front layer starts this long after the back one
local LENGTH = 0.5 -- the back layer's rays: centre to edge

-- Back against front (0 at the back, 1 at the front): the back layer has 1 / COUNT_FALLOFF
-- times the front's rays, (1 - SHORTER) of its length and BACK_WIDTH of its width
local COUNT_FALLOFF = 1 / 3
local SHORTER = 0.52
local BACK_WIDTH = 0.38
local MIDDLE_WIDTH = 1.15 -- the layers between, against the front
local COUNTER_SPIN = -0.6 -- every other layer turns the other way, slower

-- Each layer's transparency, back to front: dimmer the further out
local BACK_ALPHA = 0.25
local FRONT_ALPHA = 0

-- The glow: { size of the burst, transparency } for the glow and its hot centre
local GLOW = { 1, 0 }
local HOT = { 1.15, 0 }

-- The gleam. The burst swells by up to SWELL on a sine wave SWELL_SECONDS round; each ray
-- flares (FLARE brighter) for a short moment once every FLARE_SECONDS, each at its own time
local SWELL = 0.04
local SWELL_SECONDS = 1.8
local FLARE = 0.45
local FLARE_SECONDS = 2.4
local FLARE_SHARPNESS = 6 -- higher: shorter flares
local GOLDEN = 2.39996 -- spreads the rays' moments evenly round the wave

local rules: { Component.Rule } = {
	{
		selector = ".ui-effect-rays-ray",
		priority = 0,
		properties = { ImageColor3 = "$Primary", BackgroundTransparency = 1 },
	},
	{
		selector = ".ui-effect-rays-core",
		priority = 0,
		properties = { ImageColor3 = "$Primary", BackgroundTransparency = 1 },
	},
	{ selector = ".ui-effect-rays-ray-warning", priority = 10, properties = { ImageColor3 = "$Warning" } },
	{ selector = ".ui-effect-rays-ray-success", priority = 10, properties = { ImageColor3 = "$Success" } },
	{
		selector = ".ui-effect-rays-ray-foreground",
		priority = 10,
		properties = { ImageColor3 = "$Foreground" },
	},
	-- White light: the glow's hot centre and the front glint
	{ selector = ".ui-effect-rays-hot", priority = 20, properties = { ImageColor3 = "$White" } },
	{ selector = ".ui-effect-rays-front", priority = 20, properties = { ImageColor3 = "$White" } },
}

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

return {
	intro = FAN_STAGGER + LAYER_STAGGER + FAN_SECONDS,
	loop = true,
	fill = false, -- a centred square
	defaults = { count = 12, layers = 3, spin = 18, width = 0.28, core = true, pulse = true },
	rules = rules,
	render = function(ctx: any): Instance
		local count = math.max(1, math.floor(tonumber(ctx.option("count")) or 12))
		local layerCount = math.max(1, math.floor(tonumber(ctx.option("layers")) or 3))
		local spin = tonumber(ctx.option("spin")) or 0
		local width = tonumber(ctx.option("width")) or 0.28
		local pulsing = ctx.option("pulse") ~= false

		-- A brief flare, 0 most of the time and 1 at its peak, `phase` along its wave
		local function flare(phase: number): number
			if not pulsing then
				return 0
			end
			local x = math.sin(ctx.elapsed() / FLARE_SECONDS * 2 * math.pi + phase)
			return math.max(x, 0) ^ FLARE_SHARPNESS
		end
		local function swell(): number
			if not pulsing then
				return 0
			end
			return math.sin(ctx.elapsed() / SWELL_SECONDS * 2 * math.pi)
		end
		local function variantTag(): string
			return "ui-effect-rays-ray-" .. ctx.variant()
		end

		local layers, all, children = {}, {}, {}
		local seed = 0
		for layer = 1, layerCount do
			local t = if layerCount > 1 then (layer - 1) / (layerCount - 1) else 0
			local n = math.max(3, math.round(count * COUNT_FALLOFF ^ t))
			local length = LENGTH * (1 - SHORTER * t)
			-- the middle layers widest, for a rich gold between the thin back and the white glint
			local rayWidth = width
				* (if t > 0 and t < 1 then MIDDLE_WIDTH else BACK_WIDTH + (1 - BACK_WIDTH) * t)
			-- eased, so the middle layer is nearly as bright as the front
			local alpha = FRONT_ALPHA + (BACK_ALPHA - FRONT_ALPHA) * (1 - t) ^ 2.5
			local start = LAYER_STAGGER * (if layerCount > 1 then (layer - 1) / (layerCount - 1) else 0)
			local turn = spin * (if layer % 2 == 0 then COUNTER_SPIN else 1)
			local tags: { any } = { "ui-effect-rays-ray", `ui-effect-rays-layer-{layer}`, variantTag }
			if layer == layerCount then
				table.insert(tags, "ui-effect-rays-front")
			end

			local rays, arms = {}, {}
			for i = 1, n do
				local delay = start + (i - 1) / math.max(n - 1, 1) * FAN_STAGGER
				seed += 1
				local phase = seed * GOLDEN
				local ray = Element.new("ImageLabel", {
					Name = "Ray",
					Image = Textures.streak,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = function()
						return UDim2.fromScale(
							rayWidth,
							length * easeOut((ctx.intro() - delay) / FAN_SECONDS)
						)
					end,
					ImageTransparency = function()
						return math.clamp(alpha - FLARE * flare(phase), 0, 1)
					end,
					Tags = tags,
				})
				local arm = Element.new("Frame", {
					Name = "Arm",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Rotation = (i - 1) * 360 / n,
					ray,
				})
				table.insert(rays, ray)
				table.insert(all, ray)
				table.insert(arms, arm)
			end

			-- Each layer starts part way round from the one behind, so their rays fall between
			local offset = 360 / n * (layer - 1) / layerCount
			local wheel = Element.new("Frame", {
				Name = `Layer{layer}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = layer,
				Rotation = function()
					return (offset + ctx.elapsed() * turn) % 360
				end,
				table.unpack(arms),
			})
			table.insert(layers, { rays = rays, arms = arms, wheel = wheel })
			table.insert(children, wheel)
		end

		-- The glow over the rays' bases, growing in with them, and its hot centre
		local core = {}
		if ctx.option("core") ~= false then
			for i, glow in { GLOW, HOT } do
				local size, transparency = glow[1], glow[2]
				local tags: { any } = { "ui-effect-rays-core", variantTag }
				if i == 2 then
					table.insert(tags, "ui-effect-rays-hot")
				end
				local ring = Element.new("ImageLabel", {
					Name = if i == 2 then "Hot" else "Glow",
					Image = Textures.glow,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					ZIndex = layerCount + i,
					Size = function()
						local s = size * easeOut(ctx.intro() / FAN_SECONDS) * (1 + SWELL * 1.5 * swell())
						return UDim2.fromScale(s, s)
					end,
					ImageTransparency = transparency,
					Tags = tags,
				})
				table.insert(core, ring)
				table.insert(children, ring)
			end
		end

		local pulse = Element.new("UIScale", {
			Name = "Pulse",
			Scale = function()
				return 1 + SWELL * swell()
			end,
		})
		table.insert(children, pulse)

		ctx.handle.layers = layers
		ctx.handle.rays = all
		ctx.handle.core = core
		ctx.handle.pulse = pulse
		return Element.new("Frame", {
			Name = "Burst",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			table.unpack(children),
		})
	end,
}
