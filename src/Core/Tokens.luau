--!strict
--[[
	Design tokens: the colour palette, semantic colours and per-device densities.

	primitives  every palette colour as a Color3 attribute ("Red500", "Zinc950",
	            "White", "Black") plus radius, spacing, font and stroke tokens.

	themes      semantic colours per theme ("Primary", "Border", ...). A value is
	              a raw value              0.5, UDim.new(0, 8)
	              an alias                 "$Zinc900"
	              Tokens.over(fg, bg, a)   fg at opacity `a` over bg, composited like CSS
	                                       (e.g. a white/10% border, a primary/90 hover)
	              Tokens.mix(a, b, t)      perceptual Oklab mix, t = 0 gives a, 1 gives b
	              Tokens.oklch(L, C, H)    a literal OKLCH colour
	            Every theme must define the same keys (Universal Styling requires it).

	densities   control heights and the type scale per device class:
	              default  desktop, mouse and keyboard
	              touch    phones and tablets, 44px minimum touch targets
	              tv       consoles, 10-foot sizes
	            Every density must define the same keys too.

	Tokens.themesFor(base, options) builds light and dark themes for a base colour: base = "zinc" | "slate" | "gray" | "neutral" |
	"stone" | "mauve" | "olive" | "mist" | "taupe"; options.primary = any palette
	hue ("blue", "rose", ...) to tint the primary colour.

	A Color3 has no alpha, so translucent values are pre-composited with
	Tokens.over, which blends in sRGB exactly as a browser does. See ADR 0010.
]]

local Oklab = require(script.Parent.Oklab)
local Palette = require(script.Parent.Palette)

local Tokens = {}

local function pascal(name: string): string
	return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end

-- Attribute name for a palette colour: Tokens.name("zinc", 950) == "Zinc950"
function Tokens.name(hue: string, shade: number): string
	return pascal(hue) .. tostring(shade)
end

function Tokens.mix(a: string, b: string, t: number)
	return { kind = "mix", a = a, b = b, t = t }
end

function Tokens.over(fg: string, bg: string, alpha: number)
	return { kind = "over", a = fg, b = bg, t = alpha }
end

function Tokens.oklch(L: number, C: number, H: number): Color3
	return Oklab.fromOklch(L, C, H)
end

-- Lucy's type (ADR 0013): Nunito for text, Fredoka for display. Both ship with Roblox
-- and are the same faces the website uses. Nunito has no 500, and sets lighter than
-- Builder Sans, so each named weight maps one step heavier.
local sans = "rbxasset://fonts/families/Nunito.json"
local display = "rbxasset://fonts/families/FredokaOne.json"

local function buildPrimitives()
	local out: { [string]: any } = {
		White = Color3.new(1, 1, 1),
		Black = Color3.new(0, 0, 0),

		-- Radius (UICorner.CornerRadius); base radius 10px
		RadiusSm = UDim.new(0, 6),
		RadiusMd = UDim.new(0, 8),
		RadiusLg = UDim.new(0, 10),
		RadiusXl = UDim.new(0, 14),
		RadiusFull = UDim.new(0.5, 0),

		-- Spacing on a 4px scale (UIPadding / UIListLayout.Padding)
		Space0 = UDim.new(0, 0),
		Space1 = UDim.new(0, 4),
		Space2 = UDim.new(0, 8),
		Space3 = UDim.new(0, 12),
		Space4 = UDim.new(0, 16),
		Space5 = UDim.new(0, 20),
		Space6 = UDim.new(0, 24),
		Space8 = UDim.new(0, 32),

		-- Fonts (FontFace)
		FontSans = Font.new(sans, Enum.FontWeight.Regular),
		FontSansMedium = Font.new(sans, Enum.FontWeight.SemiBold),
		FontSansSemibold = Font.new(sans, Enum.FontWeight.Bold),
		FontSansBold = Font.new(sans, Enum.FontWeight.ExtraBold),
		FontDisplay = Font.new(display, Enum.FontWeight.Regular),

		StrokeThin = 1,
		StrokeThick = 2,
		FocusRing = 3, -- focus ring stroke in px
	}
	for _, hue in Palette.hues do
		for shade, swatch in Palette[hue] do
			out[Tokens.name(hue, shade)] = Oklab.fromOklch(swatch[1], swatch[2], swatch[3])
		end
	end
	return out
end

Tokens.primitives = buildPrimitives()

local function density(controls: { number }, text: { number })
	return {
		ControlSm = UDim2.fromOffset(0, controls[1]),
		ControlMd = UDim2.fromOffset(0, controls[2]),
		ControlLg = UDim2.fromOffset(0, controls[3]),
		ControlIcon = UDim2.fromOffset(controls[4], controls[4]),
		TextXs = text[1],
		TextSm = text[2],
		TextBase = text[3],
		TextLg = text[4],
		TextXl = text[5],
		Text2xl = text[6],
		Text3xl = text[7],
		Text4xl = text[8],
	}
end

Tokens.densities = {
	-- 32 / 36 / 40 px controls and the base type scale
	default = density({ 32, 36, 40, 36 }, { 12, 14, 16, 18, 20, 24, 30, 36 }),
	-- Apple HIG / Material: 44px minimum touch targets
	touch = density({ 40, 44, 48, 44 }, { 12, 14, 16, 18, 20, 24, 30, 36 }),
	-- Console, read from a sofa
	tv = density({ 44, 52, 60, 52 }, { 14, 16, 18, 22, 24, 28, 34, 42 }),
}
Tokens.defaultDensity = "default"

Tokens.bases = { "zinc", "slate", "gray", "neutral", "stone", "mauve", "olive", "mist", "taupe" }

--[[
	Light and dark semantic themes for a base colour (see ADR 0010).
	options.primary: a palette hue for Primary/Ring (default: the base colour).
]]
function Tokens.themesFor(base: string?, options: { primary: string? }?)
	local b = base or "zinc"
	if Palette[b] == nil then
		error(`[Lucy] unknown base colour "{b}"`, 2)
	end
	local function c(shade: number): string
		return "$" .. Tokens.name(b, shade)
	end
	local tint = options and options.primary
	if tint and Palette[tint] == nil then
		error(`[Lucy] unknown primary hue "{tint}"`, 2)
	end
	local function p(shade: number, fallback: string): string
		return if tint then "$" .. Tokens.name(tint, shade) else fallback
	end

	local light = {
		Background = "$White",
		Foreground = c(950),
		Card = "$White",
		CardForeground = c(950),
		Popover = "$White",
		PopoverForeground = c(950),
		Primary = p(600, c(900)),
		PrimaryForeground = p(50, c(50)),
		PrimaryHover = Tokens.over("$Primary", "$Background", 0.9),
		Secondary = c(100),
		SecondaryForeground = c(900),
		SecondaryHover = Tokens.over("$Secondary", "$Background", 0.8),
		Muted = c(100),
		MutedForeground = c(500),
		Accent = c(100),
		AccentForeground = c(900),
		Destructive = "$Red600",
		DestructiveForeground = "$White",
		DestructiveHover = Tokens.over("$Destructive", "$Background", 0.9),
		Border = c(200),
		Input = c(200),
		Ring = p(400, c(400)),
		Overlay = "$Black",
		OverlayTransparency = 0.5,
		Success = "$Green600",
		SuccessForeground = "$White",
		Warning = "$Amber500",
		WarningForeground = c(950),
		Info = "$Blue600",
		InfoForeground = "$White",
	}

	local dark = {
		Background = c(950),
		Foreground = c(50),
		Card = c(900),
		CardForeground = c(50),
		Popover = c(900),
		PopoverForeground = c(50),
		Primary = p(500, c(200)),
		PrimaryForeground = p(50, c(900)),
		PrimaryHover = Tokens.over("$Primary", "$Background", 0.9),
		Secondary = c(800),
		SecondaryForeground = c(50),
		SecondaryHover = Tokens.over("$Secondary", "$Background", 0.8),
		Muted = c(800),
		MutedForeground = c(400),
		Accent = c(800),
		AccentForeground = c(50),
		Destructive = "$Red400",
		DestructiveForeground = "$White",
		DestructiveHover = Tokens.over("$Destructive", "$Background", 0.9),
		-- border white/10%, input white/15% over the background
		Border = Tokens.over("$White", "$Background", 0.1),
		Input = Tokens.over("$White", "$Background", 0.15),
		-- Lighter than Primary so the ring stays visible around a focused primary button.
		Ring = p(300, c(500)),
		Overlay = "$Black",
		OverlayTransparency = 0.3,
		Success = "$Green500",
		SuccessForeground = c(950),
		Warning = "$Amber400",
		WarningForeground = c(950),
		Info = "$Blue500",
		InfoForeground = "$White",
	}

	return { light = light, dark = dark }
end

Tokens.themes = Tokens.themesFor("zinc")
Tokens.defaultTheme = "dark"

local function isAlias(value: any): boolean
	return type(value) == "string" and string.sub(value, 1, 1) == "$"
end
Tokens.isAlias = isAlias

-- Computes a derived token given a resolver for "$Name" references.
function Tokens.compute(derived: { [string]: any }, resolve: (string) -> any): any
	local kind = derived.kind
	if kind == "mix" or kind == "over" then
		local a = if isAlias(derived.a) then resolve(derived.a) else derived.a
		local b = if isAlias(derived.b) then resolve(derived.b) else derived.b
		if typeof(a) ~= "Color3" or typeof(b) ~= "Color3" then
			error(`[Lucy] {kind} needs two colours, got {typeof(a)} and {typeof(b)}`, 0)
		end
		if kind == "mix" then
			return Oklab.mix(a, b, derived.t)
		end
		-- Alpha compositing in gamma sRGB, as CSS does: bg * (1 - a) + fg * a
		return b:Lerp(a, derived.t)
	end
	error(`[Lucy] unknown derived token kind "{tostring(derived.kind)}"`, 0)
end

--[[
	Turns one theme's values into attribute-ready values: aliases stay as "$Name"
	strings (Universal Styling follows them), derived values (mix/over) are
	computed to a Color3 now. Errors if a reference cannot be resolved.
]]
function Tokens.resolveTheme(values: { [string]: any }, primitives: { [string]: any }): { [string]: any }
	local resolving = {}

	local function lookup(ref: string, depth: number): any
		if depth > 16 then
			error(`[Lucy] token alias loop at "{ref}"`, 0)
		end
		local name = string.sub(ref, 2)
		local value = values[name]
		if value == nil then
			value = primitives[name]
		end
		if value == nil then
			error(`[Lucy] unknown token "{ref}"`, 0)
		end
		if isAlias(value) then
			return lookup(value, depth + 1)
		end
		if type(value) == "table" then
			if resolving[name] then
				error(`[Lucy] token "{name}" refers to itself`, 0)
			end
			resolving[name] = true
			local computed = Tokens.compute(value, function(r)
				return lookup(r, depth + 1)
			end)
			resolving[name] = nil
			return computed
		end
		return value
	end

	local out = {}
	for key, value in values do
		if type(value) == "table" then
			out[key] = lookup("$" .. key, 0)
		else
			if isAlias(value) then
				lookup(value, 0) -- validate now, keep the alias for the engine
			end
			out[key] = value
		end
	end
	return out
end

return Tokens
