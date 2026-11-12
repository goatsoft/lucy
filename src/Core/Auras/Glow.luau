--!strict
--[[
	glow: a soft halo round the wearer, sparks rising off it and a light in front of them, in a
	theme colour. The halo breathes while it runs; it opens up over 0.6 s and fades out over 0.5 s.

	options:
		token    the theme colour ("Primary"); any colour token, e.g. "Warning" for gold
		size     the halo's size in studs (12: round the whole body, well past it)
		sparks   sparks a second at full strength (20); 0 for none
		light    the light's brightness (2.5); 0 for none
		at       the attachment it is centred on ("WaistCenterAttachment")
]]

local Element = require(script.Parent.Parent.Element)
local Textures = require(script.Parent.Parent.Parent.Components.Effects.Textures)

local INTRO: number, OUTRO: number = 0.6, 0.5

return {
	intro = INTRO,
	outro = OUTRO,
	loop = true,
	defaults = { token = "Primary", size = 12, sparks = 20, light = 2.5, at = "WaistCenterAttachment" },
	build = function(ctx: any)
		local at = ctx.attachment(ctx.option("at"))
		local size = ctx.option("size") :: number

		-- How far open it is: the opening, the closing and the strength together
		local function open(): number
			local o = math.min(ctx.intro() / INTRO, 1) * (1 - math.min(ctx.outro() / OUTRO, 1))
			return o * ctx.strength()
		end
		-- A slow breath while it runs (still with reduced motion: elapsed stays 0)
		local function breath(): number
			return 0.9 + 0.1 * math.sin(ctx.elapsed() * 2)
		end

		-- The halo: the glow picture on a billboard at the wearer's middle, so it shows the moment the
		-- aura opens (no particles to build up) and the body hides the part of it behind them
		local haloImage = Element.new("ImageLabel", {
			Name = "Glow",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Textures.glow,
			ImageTransparency = function()
				return 1 - 0.95 * open() * breath()
			end,
		})
		Element.new("BillboardGui", {
			Name = "Halo",
			Size = UDim2.fromScale(size, size),
			LightInfluence = 0,
			Brightness = 3,
			ResetOnSpawn = false,
			Enabled = function()
				return open() > 0
			end,
			haloImage,
			Parent = at,
		})

		local sparkRate = ctx.option("sparks") :: number
		local sparks = Element.new("ParticleEmitter", {
			Name = "Sparks",
			Texture = Textures.glow,
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(180, 180), -- out of the body every way, then up
			Speed = NumberRange.new(3, 5),
			Acceleration = Vector3.new(0, 3, 0),
			Drag = 2,
			Lifetime = NumberRange.new(1.2, 2),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Rate = function()
				local thin = if ctx.reducedMotion() then 0.3 else 1
				return sparkRate * open() * thin
			end,
			Enabled = function()
				return sparkRate > 0 and open() > 0
			end,
			Parent = at,
		})

		-- The light sits in front of the wearer, chest high, so it lights their face and chest
		-- (inside the body it would light nothing anyone sees)
		local lightAt = ctx.attachment(ctx.option("at"))
		lightAt.Position += Vector3.new(0, size * 0.12, -size * 0.25)
		local lightLevel = ctx.option("light") :: number
		local light = Element.new("PointLight", {
			Name = "Light",
			Range = size,
			Shadows = false,
			Brightness = function()
				return lightLevel * open() * breath()
			end,
			Enabled = function()
				return lightLevel > 0 and open() > 0
			end,
			Parent = lightAt,
		})

		-- The theme's colour now, and again whenever the theme changes
		local function paint()
			local colour = ctx.color(ctx.option("token"))
			haloImage.ImageColor3 = colour
			sparks.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.35))
			light.Color = colour
		end
		paint()
		if ctx.app and ctx.app.theme then
			ctx.give(ctx.app.theme.Changed:Connect(paint))
		end
	end,
}
