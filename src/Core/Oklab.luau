--[[
	Oklab / OKLCH colour maths (Björn Ottosson, https://bottosson.github.io/posts/oklab/).

	Tailwind v4 and shadcn define colours in OKLCH. Roblox renders sRGB Color3, so
	tokens are authored in OKLCH and converted here. Vivid shades (blue-500,
	green-500 ...) sit outside sRGB; Oklab.gamut decides how they are brought in:
		"clip"   clamp each channel (default; matches Tailwind's published sRGB values)
		"chroma" lower chroma at constant lightness and hue (closer to CSS Color 4 mapping)

		Oklab.fromOklch(0.637, 0.237, 25.33)  --> Color3 (Tailwind red-500)
		Oklab.palette("zinc", 900)            --> Color3
		Oklab.mix(a, b, 0.1)                  --> perceptual mix, 10% of b
		Oklab.adjust(color, { l = -0.05 })    --> shift lightness / chroma / hue
		Oklab.toOklch(color)                  --> L, C, H

	The pure functions (*Rgb) work on plain numbers so they run outside Roblox too.
]]

local Palette = require(script.Parent.Palette)

local Oklab = {}

local EPSILON = 1e-6

Oklab.gamut = "clip" :: "clip" | "chroma"

local function cbrt(x: number): number
	return if x < 0 then -((-x) ^ (1 / 3)) else x ^ (1 / 3)
end

local function toLinear(c: number): number
	return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

local function toGamma(c: number): number
	return if c <= 0.0031308 then 12.92 * c else 1.055 * c ^ (1 / 2.4) - 0.055
end

-- Oklab -> linear sRGB (may be out of 0..1).
function Oklab.oklabToLinearRgb(L: number, a: number, b: number): (number, number, number)
	local l_ = L + 0.3963377774 * a + 0.2158037573 * b
	local m_ = L - 0.1055613458 * a - 0.0638541728 * b
	local s_ = L - 0.0894841775 * a - 1.2914855480 * b
	local l, m, s = l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_
	return 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
end

-- Gamma-encoded sRGB (0..1) -> Oklab.
function Oklab.rgbToOklab(r: number, g: number, b: number): (number, number, number)
	r, g, b = toLinear(r), toLinear(g), toLinear(b)
	local l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
	local m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
	local s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
	return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end

function Oklab.oklchToOklab(L: number, C: number, H: number): (number, number, number)
	local h = math.rad(H)
	return L, C * math.cos(h), C * math.sin(h)
end

function Oklab.oklabToOklch(L: number, a: number, b: number): (number, number, number)
	local C = math.sqrt(a * a + b * b)
	local H = if C < 1e-4 then 0 else math.deg(math.atan2(b, a)) % 360
	return L, C, H
end

local function inGamut(r: number, g: number, b: number): boolean
	return r >= -EPSILON and r <= 1 + EPSILON and g >= -EPSILON and g <= 1 + EPSILON and b >= -EPSILON and b <= 1 + EPSILON
end

function Oklab.inGamut(L: number, C: number, H: number): boolean
	return inGamut(Oklab.oklabToLinearRgb(Oklab.oklchToOklab(L, C, H)))
end

-- OKLCH -> gamma sRGB numbers in 0..1, gamut mapped per Oklab.gamut.
function Oklab.oklchToRgb(L: number, C: number, H: number): (number, number, number)
	if L >= 1 then
		return 1, 1, 1
	elseif L <= 0 then
		return 0, 0, 0
	end
	local r, g, b = Oklab.oklabToLinearRgb(Oklab.oklchToOklab(L, C, H))
	if Oklab.gamut == "chroma" and not inGamut(r, g, b) then
		local low, high = 0, C
		for _ = 1, 24 do
			local mid = (low + high) / 2
			if Oklab.inGamut(L, mid, H) then
				low = mid
			else
				high = mid
			end
		end
		r, g, b = Oklab.oklabToLinearRgb(Oklab.oklchToOklab(L, low, H))
	end
	return math.clamp(toGamma(math.clamp(r, 0, 1)), 0, 1),
		math.clamp(toGamma(math.clamp(g, 0, 1)), 0, 1),
		math.clamp(toGamma(math.clamp(b, 0, 1)), 0, 1)
end

function Oklab.oklabToRgb(L: number, a: number, b: number): (number, number, number)
	return Oklab.oklchToRgb(Oklab.oklabToOklch(L, a, b))
end

-- Perceptual mix in Oklab: t = 0 gives a, t = 1 gives b.
function Oklab.mixRgb(r1: number, g1: number, b1: number, r2: number, g2: number, b2: number, t: number)
	local L1, a1, bb1 = Oklab.rgbToOklab(r1, g1, b1)
	local L2, a2, bb2 = Oklab.rgbToOklab(r2, g2, b2)
	return Oklab.oklabToRgb(L1 + (L2 - L1) * t, a1 + (a2 - a1) * t, bb1 + (bb2 - bb1) * t)
end

-- Color3 helpers (Roblox only) -------------------------------------------------

function Oklab.fromOklch(L: number, C: number, H: number): Color3
	return Color3.new(Oklab.oklchToRgb(L, C, H))
end

function Oklab.fromOklab(L: number, a: number, b: number): Color3
	return Color3.new(Oklab.oklabToRgb(L, a, b))
end

function Oklab.toOklab(color: Color3): (number, number, number)
	return Oklab.rgbToOklab(color.R, color.G, color.B)
end

function Oklab.toOklch(color: Color3): (number, number, number)
	return Oklab.oklabToOklch(Oklab.toOklab(color))
end

function Oklab.mix(a: Color3, b: Color3, t: number): Color3
	return Color3.new(Oklab.mixRgb(a.R, a.G, a.B, b.R, b.G, b.B, t))
end

-- Shift lightness (l), chroma (c) and hue (h, degrees) in OKLCH.
function Oklab.adjust(color: Color3, delta: { l: number?, c: number?, h: number? }): Color3
	local L, C, H = Oklab.toOklch(color)
	return Oklab.fromOklch(
		math.clamp(L + (delta.l or 0), 0, 1),
		math.max(0, C + (delta.c or 0)),
		(H + (delta.h or 0)) % 360
	)
end

-- Euclidean distance in Oklab (deltaEOK). ~0.02 is a just-noticeable difference.
function Oklab.distance(a: Color3, b: Color3): number
	local L1, a1, b1 = Oklab.toOklab(a)
	local L2, a2, b2 = Oklab.toOklab(b)
	return math.sqrt((L2 - L1) ^ 2 + (a2 - a1) ^ 2 + (b2 - b1) ^ 2)
end

-- A Tailwind palette colour: Oklab.palette("blue", 500)
function Oklab.palette(hue: string, shade: number): Color3
	local swatch = Palette[hue] and Palette[hue][shade]
	if not swatch then
		error(`[Lucy] no Tailwind colour {hue}-{shade}`, 2)
	end
	return Oklab.fromOklch(swatch[1], swatch[2], swatch[3])
end

return Oklab
