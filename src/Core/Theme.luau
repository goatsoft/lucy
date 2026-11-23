--!strict
--[[
	Theme: builds the Universal Styling sheet graph and switches themes (ADR 0003, 0052).

		Folder <name>
		├─ StyleSheet "Tokens"            attributes = primitives (palette, radius, space, fonts)
		├─ StyleSheet "Theme_light"       StyleDerive -> Tokens, attributes = semantic colours
		├─ StyleSheet "Theme_dark"        StyleDerive -> Tokens, attributes = semantic colours
		├─ StyleSheet "Density_default"   control heights + type scale
		├─ StyleSheet "Density_touch"
		├─ StyleSheet "Density_tv"
		├─ StyleSheet "Values"            StyleDerive -> active Theme_*, StyleDerive -> active Density_*
		├─ StyleSheet "Lucy"              StyleDerive -> Values; Lucy's base and component rules
		├─ StyleSheet "Game"              StyleDerive -> Lucy; the game's rules
		├─ StyleSheet "Fixed"             StyleDerive -> Game; Lucy's rules for what a component is,
		│                                 not how it looks (an untinted icon's own colours)
		├─ StyleSheet "Design"            StyleDerive -> Fixed; live rules (added and removed in play)
		└─ StyleSheet "Game_40" ...       a layer's rules of one Priority, StyleDerive -> Values

	The layers (ADR 0052): a sheet's own rules beat every rule of the sheet it derives, whatever
	their Priority, so a game's rule beats Lucy's look, Lucy's fixed rules beat the game's (a
	picture that keeps its own colours is not a look to restyle), and a live rule beats all.
	Priority orders rules within a layer, and at equal Priority the rule added later wins. Adding
	a rule costs in proportion to the rules already in its sheet, so a layer keeps no rules of its
	own: it derives a sheet per Priority, lowest first (of sibling derives the later wins, whatever
	their rules' Priority, so the order is the Priority's), and a rule goes into its Priority's
	sheet. Building the layers is then about the sum of each sheet's size squared, not the
	layer's. Each of those sheets derives Values, where its tokens are. Design, the live layer,
	is small and a sheet of its own (a designer's rules go straight into it).

	ScreenGuis get a StyleLink to "Design" (theme:link). Switching theme or density only
	re-points a StyleDerive on Values; tokens resolve through the derives, so every layer and every
	linked gui restyles at once.

	Base rules take control of Roblox defaults inside linked guis: no default borders, no
	AutoButtonColor tinting, themed text, and our own focus ring (".ui-focus-visible") in place of
	the engine's selection image.

	Rules come in groups, by key. A rule is
		{ selector = ".ui-button:Hover", priority = 20,
		  properties = { BackgroundColor3 = "$PrimaryHover" },
		  transitions = { BackgroundColor3 = TweenInfo.new(0.12) } }
		{ selector = ".ui-icon-untinted", fixed = true, properties = { ImageColor3 = "$White" } }
		                                     -- fixed: in the Fixed layer, over the game's rules

		Theme.declare(key, rules)            -- Lucy's own groups, when their modules load: every
		                                     -- theme made afterwards has them in its Lucy layer
		theme:addRules(key, rules)           -- a game's group, in the Game layer
		theme:addRules(key, rules, { layer = "live" })  -- one that comes and goes while playing
		theme:removeRules(key) ; theme:hasRules(key)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(script.Parent.Signal)
local Tokens = require(script.Parent.Tokens)

local Theme = {}
Theme.__index = Theme

export type Rule = {
	selector: string,
	priority: number?,
	fixed: boolean?,
	scoped: boolean?,
	properties: { [string]: any },
	transitions: { [string]: any }?,
}

export type Theme = typeof(setmetatable(
	{} :: {
		Changed: Signal.Signal,
		DensityChanged: Signal.Signal,
		MetricsChanged: Signal.Signal,
		folder: Folder,
		design: StyleSheet,
		_layers: { [string]: StyleSheet },
		_bands: { [string]: { [number]: StyleSheet } },
		_values: StyleSheet,
		_colorNames: { string },
		_colorGroups: { [string]: { [string]: boolean } },
		_colorCompounds: { [string]: { Compound } },
		_rules: { [string]: { StyleRule } },
		_themes: { [string]: StyleSheet },
		_densities: { [string]: StyleSheet },
		_densityValues: { [string]: { [string]: any } },
		_grow: ((size: number) -> number)?,
		_seeThrough: { [string]: { [string]: number } },
		_transparency: number,
		_tokens: StyleSheet,
		_themeDerive: StyleDerive,
		_densityDerive: StyleDerive,
		_current: string,
		_density: string,
	},
	Theme
))

local RESET, FOCUS = -100, 100

local GUI_CLASSES = {
	"Frame",
	"TextLabel",
	"TextButton",
	"TextBox",
	"ImageLabel",
	"ImageButton",
	"ScrollingFrame",
	"CanvasGroup",
	"ViewportFrame",
	"VideoFrame",
}

Theme.baseRules = {} :: { Rule }
for _, className in GUI_CLASSES do
	table.insert(
		Theme.baseRules,
		{ selector = className, priority = RESET, properties = { BorderSizePixel = 0 } }
	)
end
for _, className in { "TextLabel", "TextButton", "TextBox" } do
	table.insert(Theme.baseRules, {
		selector = className,
		priority = RESET,
		properties = { FontFace = "$FontSans", TextColor3 = "$Foreground", TextSize = "$TextSm" },
	})
end
for _, className in { "TextButton", "ImageButton" } do
	table.insert(
		Theme.baseRules,
		{ selector = className, priority = RESET, properties = { AutoButtonColor = false } }
	)
end
table.insert(Theme.baseRules, {
	selector = "TextBox",
	priority = RESET,
	properties = { PlaceholderColor3 = "$MutedForeground", ClearTextOnFocus = false },
})
table.insert(Theme.baseRules, {
	selector = "ScrollingFrame",
	priority = RESET,
	properties = { ScrollBarImageColor3 = "$MutedForeground", ScrollBarThickness = 6 },
})
-- Our focus ring, shown for keyboard and gamepad navigation: strokes of its own that InputManager
-- puts inside what has focus, so an outline a game gives the element never covers it. Sharp at
-- the edge, then a softer feather and a faint halo further in, so it reads as a glow and not as
-- one more border. All inside the edge, so a ring never spills past its element or gets clipped.
-- A game recolours it with one rule on `.its-tag > .ui-focus-ring-part`.
for _, part in
	{
		{ ".ui-focus-ring", "$FocusRing", 0 },
		{ ".ui-focus-feather", "$FocusFeather", 0.6 },
		{ ".ui-focus-halo", "$FocusHalo", 0.85 },
	} :: { { any } }
do
	table.insert(Theme.baseRules, {
		selector = part[1],
		priority = FOCUS,
		properties = {
			Color = "$Ring",
			Thickness = part[2],
			Transparency = part[3],
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	})
end

-- Rows that ring one part instead (Component.partRing, tagged ui-ring-host): the row gets no ring
-- of its own (InputManager) and the part's ring shows.
table.insert(Theme.baseRules, {
	selector = ".ui-part-ring-corner",
	priority = 0,
	properties = { CornerRadius = "$RadiusFull" },
})
table.insert(Theme.baseRules, {
	selector = ".ui-part-ring-stroke",
	priority = 0,
	properties = {
		Color = "$Ring",
		Thickness = "$FocusRing",
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
	},
})
table.insert(Theme.baseRules, {
	selector = ".ui-ring-host.ui-focus-visible >> .ui-part-ring-stroke",
	priority = FOCUS,
	properties = { Transparency = 0 },
})

-- The layers rules go in, by the name addRules takes (ADR 0052)
local LAYERS = { lucy = "Lucy", game = "Game", live = "Design" }

-- The sheet a rule of `priority` goes in, in the layer `name`: the layer itself if it is not
-- split (Design), else its Priority's own sheet, made when first needed and derived by the layer
-- in Priority order, after the layer below and every lower Priority's (see the top)
local function sheetFor(self: any, name: string, priority: number): StyleSheet
	local bands = self._bands[name]
	if not bands then
		return self._layers[name]
	end
	local sheet = bands[priority]
	if sheet then
		return sheet
	end
	sheet = Instance.new("StyleSheet")
	sheet.Name = `{name}_{priority}`
	local values = Instance.new("StyleDerive")
	values.Name = "Values"
	values.StyleSheet = self._values
	values.Parent = sheet
	sheet.Parent = self.folder
	bands[priority] = sheet
	-- The derives of higher Priorities step out, so this one lands before them
	local layer = self._layers[name]
	local later = {}
	for _, child in layer:GetChildren() do
		local of = child:GetAttribute("LucyPriority")
		if child:IsA("StyleDerive") and type(of) == "number" and of > priority then
			table.insert(later, child)
		end
	end
	table.sort(later, function(a: Instance, b: Instance): boolean
		return (a:GetAttribute("LucyPriority") :: number) < (b:GetAttribute("LucyPriority") :: number)
	end)
	for _, derive in later do
		derive.Parent = nil
	end
	local derive = Instance.new("StyleDerive")
	derive.Name = sheet.Name
	derive.StyleSheet = sheet
	derive:SetAttribute("LucyPriority", priority)
	derive.Parent = layer
	for _, derive in later do
		derive.Parent = layer
	end
	return sheet
end

--[[
	Named colours (ADR 0052). A theme's `colors` names them ({ hype = "$Yellow400" }); each gets a
	token of its own (Hype) and the shades below, worked out as Primary's are, plus any a game adds
	(`colorRecipes`, by name: Glow = function(colour, shade) return Tokens.mix(...) end, where
	colour is "$Hype" and shade("Soft") is "$HypeSoft"). Primary gets the shades it lacks, and a
	token the theme sets itself is kept.

	A rule written in $Color, $ColorHover, $ColorForeground... is compiled: once with Primary's
	tokens (unless scoped = true) and once per colour, with .ui-color-<name> on its first compound,
	so it applies to what a coloured container (Core/Color) has tagged. A scoped rule with no
	$Color holds in any colour: one copy, on .ui-colored.

	A colour may name the groups it colours (ADR 0053): { "$Orange500", on = { "danceLabTones" } }.
	It is then compiled only for the $Color rules of those groups (a component's kind, a declared
	key, an addRules key); a colour without `on` is compiled for every group.
]]
Theme.SHADES = {
	{
		"Hover",
		function(colour: string): any
			return Tokens.over(colour, "$Background", 0.9)
		end,
	},
	{
		"Foreground",
		function(colour: string): any
			return Tokens.onColor(colour)
		end,
	},
	-- A quiet wash of the colour on a card, and quiet words that read on it
	{
		"Soft",
		function(colour: string): any
			return Tokens.over(colour, "$Card", 0.16)
		end,
	},
	{
		"MutedTint",
		function(colour: string): any
			return Tokens.mix(colour, "$White", 0.55)
		end,
	},
	{
		"MutedForeground",
		function(_colour: string, shade: (string) -> string): any
			return Tokens.readable(shade("Soft"), shade("MutedTint"), shade("MutedTint"))
		end,
	},
	{
		"Border",
		function(colour: string): any
			return colour
		end,
	},
	-- A deep shade of it, for a hard shadow that still belongs to the colour
	{
		"Shadow",
		function(colour: string): any
			return Tokens.mix(colour, "$Black", 0.62)
		end,
	},
} :: { { any } }

-- "genre-house" -> "GenreHouse", the colour's token
function Theme.tokenOf(name: string): string
	return (string.gsub(string.gsub(name, "^%l", string.upper), "%-(%w)", string.upper))
end

-- Whether a rule's properties are written in $Color...
local function isColorToken(value: any): boolean
	return type(value) == "string" and string.match(value, "^%$Color%u?%w*$") ~= nil
end
local function usesColor(properties: { [string]: any }): boolean
	for _, value in properties do
		if isColorToken(value) then
			return true
		end
	end
	return false
end

-- The properties with $Color... as the colour's own tokens: $ColorHover -> $HypeHover
local function recolor(properties: { [string]: any }, token: string): { [string]: any }
	local out = {}
	for property, value in properties do
		out[property] = if isColorToken(value) then "$" .. token .. string.sub(value, 7) else value
	end
	return out
end

-- A tag on the first compound of each part of a selector list, before its states and pseudo
-- instances: (".a:Hover > .b", "x") -> ".a.x:Hover > .b"
local function onFirstCompound(selector: string, tag: string): string
	local parts = {}
	for _, part in string.split(selector, ",") do
		local lead: string = string.match(part, "^%s*") or ""
		local body = string.sub(part, #lead + 1)
		local stop = string.find(body, "[%s>]") or (#body + 1)
		local compound, rest = string.sub(body, 1, stop - 1), string.sub(body, stop)
		local state = string.find(compound, ":", 1, true)
		compound = if state
			then string.sub(compound, 1, state - 1) .. "." .. tag .. string.sub(compound, state)
			else compound .. "." .. tag
		table.insert(parts, lead .. compound .. rest)
	end
	return table.concat(parts, ",")
end

-- The selector for a colour: ".a:Hover > .b" -> ".a.ui-color-hype:Hover > .b"
function Theme.colorSelector(selector: string, name: string): string
	return onFirstCompound(selector, "ui-color-" .. name)
end

-- What the first compound of a selector part asks of an element: its class and tags, without
-- states and pseudo instances (".a.b:Hover::UIStroke" -> tags a and b)
export type Compound = { class: string?, tags: { string } }
local function firstCompounds(selector: string): { Compound }
	local out = {}
	for _, part in string.split(selector, ",") do
		local body = string.match(part, "^%s*(.-)%s*$") or ""
		local stop = string.find(body, "[%s>]") or (#body + 1)
		local compound = string.sub(body, 1, stop - 1)
		local state = string.find(compound, ":", 1, true)
		if state then
			compound = string.sub(compound, 1, state - 1)
		end
		local tags = {}
		for tag in string.gmatch(compound, "%.([%w%-_]+)") do
			table.insert(tags, tag)
		end
		table.insert(out, { class = string.match(compound, "^(%a%w*)"), tags = tags })
	end
	return out
end

local function matchesCompound(instance: Instance, compound: Compound): boolean
	if compound.class and not instance:IsA(compound.class) then
		return false
	end
	for _, tag in compound.tags do
		if not instance:HasTag(tag) then
			return false
		end
	end
	return true
end

-- Each theme's values with every named colour and its shades added, and the colours' names
local function withColors(
	themes: { [string]: { [string]: any } },
	colors: { [string]: any }?,
	recipes: { [string]: (string, (string) -> string) -> any }?
): ({ [string]: { [string]: any } }, { string }, { [string]: { [string]: boolean } })
	local own: { [string]: (string, (string) -> string) -> any } = recipes or {}
	local names = {}
	-- Each colour's value, and the groups it colours when it names them (ADR 0053)
	local named: { [string]: any } = {}
	local groups: { [string]: { [string]: boolean } } = {}
	local given: { [string]: any } = colors or {}
	for name, entry in given do
		-- A table with no `kind` is a colour with its groups; a derived token (Tokens.mix...) has one
		if type(entry) == "table" and entry.kind == nil then
			if entry[1] == nil then
				error(
					`[Lucy] colour "{tostring(name)}": a colour with \`on\` takes its value first, as in \{ "$Yellow400", on = \{ "danceLabTones" } }`,
					4
				)
			end
			local on = entry.on
			if on ~= nil then
				if type(on) ~= "table" then
					error(
						`[Lucy] colour "{tostring(name)}": a colour with \`on\` lists the names of rule groups`,
						4
					)
				end
				local set = {}
				for _, group in on do
					if type(group) ~= "string" then
						error(
							`[Lucy] colour "{tostring(name)}": a colour with \`on\` lists the names of rule groups`,
							4
						)
					end
					set[group] = true
				end
				groups[name] = set
			end
			named[name] = entry[1]
		else
			named[name] = entry
		end
	end
	for name in named do
		if type(name) ~= "string" or not string.match(name, "^%l[%l%d%-]*$") then
			error(
				`[Lucy] a colour's name is lower case, words joined by "-" ("genre-house"), not "{tostring(
					name
				)}"`,
				4
			)
		end
		table.insert(names, name)
	end
	table.sort(names)
	local shades: { { any } } = table.clone(Theme.SHADES)
	local recipeNames = {}
	for shadeName in own do
		table.insert(recipeNames, shadeName)
	end
	table.sort(recipeNames)
	for _, shadeName in recipeNames do
		local entry: { any } = { shadeName }
		entry[2] = own[shadeName]
		table.insert(shades, entry)
	end
	local out = {}
	for themeName, values in themes do
		local v = table.clone(values)
		local function add(token: string, base: any)
			if v[token] == nil then
				v[token] = base
			end
			if v[token] == nil then
				return
			end
			local function shade(name: string): string
				return "$" .. token .. name
			end
			for _, entry in shades do
				local key = token .. entry[1]
				if v[key] == nil then
					v[key] = entry[2]("$" .. token, shade)
				end
			end
		end
		-- Primary's own shades where the theme has what they are made from (a theme of a few tokens,
		-- in a spec, may not); a named colour's are always made, and say what is missing
		if v.Primary ~= nil and v.Background ~= nil and v.Card ~= nil then
			add("Primary", nil)
		end
		for _, name in names do
			add(Theme.tokenOf(name), named[name])
		end
		out[themeName] = v
	end
	return out, names, groups
end

-- Groups of rules declared when their modules load, in the order they loaded: every theme made
-- afterwards builds them into its Lucy layer at once, so nothing is added while a game runs
local declared: { { key: string, rules: { Rule } } } = {}
local declaredKeys: { [string]: boolean } = {}

--[[
	Declares a group of Lucy's rules, once, when its module loads (Component.define does it for a
	component's rules). A theme made afterwards has the group from the start. Declaring a key again
	does nothing.
]]
function Theme.declare(key: string, rules: { Rule })
	if declaredKeys[key] then
		return
	end
	declaredKeys[key] = true
	table.insert(declared, { key = key, rules = rules })
end

-- Takes a declared group off the list (for specs that declare their own)
function Theme._forget(key: string)
	if not declaredKeys[key] then
		return
	end
	declaredKeys[key] = nil
	for index, group in declared do
		if group.key == key then
			table.remove(declared, index)
			break
		end
	end
end

local function keySet(t: { [string]: any }): string
	local out = {}
	for key in t do
		table.insert(out, key)
	end
	table.sort(out)
	return table.concat(out, ",")
end

local function validateSets(sets: { [string]: { [string]: any } }, what: string)
	local reference, referenceName
	for name, values in sets do
		local keys = keySet(values)
		if reference == nil then
			reference, referenceName = keys, name
		elseif keys ~= reference then
			error(
				`[Lucy] {what} "{name}" has different tokens to "{referenceName}"; they must share a token set`,
				4
			)
		end
	end
	if reference == nil then
		error(`[Lucy] at least one {what} is required`, 4)
	end
end

local function setAttributes(instance: Instance, values: { [string]: any })
	for key, value in values do
		instance:SetAttribute(key, value)
	end
end

local function pickDefault(sets, wanted, fallback)
	if wanted ~= nil and sets[wanted] ~= nil then
		return wanted
	end
	if sets[fallback] ~= nil then
		return fallback
	end
	return (next(sets))
end

function Theme.new(config: { [string]: any }?): Theme
	local options: { [string]: any } = config or {}
	local primitives = options.primitives or Tokens.primitives
	local themes, colorNames, colorGroups =
		withColors(options.themes or Tokens.themes, options.colors, options.colorRecipes)
	local densities = options.densities or Tokens.densities
	validateSets(themes, "theme")
	validateSets(densities, "density")

	-- Fields are filled in below, once the instances they point at exist.
	local self: Theme = setmetatable({} :: any, Theme)
	self.Changed = Signal.new()
	self.DensityChanged = Signal.new()
	self.MetricsChanged = Signal.new()
	self._densityValues = densities
	self._colorNames = colorNames
	self._colorGroups = colorGroups
	self._colorCompounds = {}
	self._rules = {}
	self._themes = {}
	self._densities = {}
	self._seeThrough = {}
	self._transparency = 1

	local folder = Instance.new("Folder")
	folder.Name = options.name or "LucyStyles"
	self.folder = folder

	local tokens = Instance.new("StyleSheet")
	tokens.Name = "Tokens"
	setAttributes(tokens, primitives)
	tokens.Parent = folder
	self._tokens = tokens

	for name, values in themes do
		local sheet = Instance.new("StyleSheet")
		sheet.Name = "Theme_" .. name
		local derive = Instance.new("StyleDerive")
		derive.StyleSheet = tokens
		derive.Parent = sheet
		-- Derived tokens (mix/over) are computed against this theme's own values.
		local resolved = Tokens.resolveTheme(values, primitives)
		setAttributes(sheet, resolved)
		sheet.Parent = folder
		self._themes[name] = sheet
		-- See-through tokens and their designed values, for setTransparency.
		local seeThrough = {}
		for token, value in resolved do
			if type(value) == "number" and string.sub(token, -12) == "Transparency" then
				seeThrough[token] = value
			end
		end
		self._seeThrough[name] = seeThrough
	end

	for name, values in densities do
		local sheet = Instance.new("StyleSheet")
		sheet.Name = "Density_" .. name
		setAttributes(sheet, values)
		sheet.Parent = folder
		self._densities[name] = sheet
	end

	-- The values every layer reads its tokens from: the active theme and density
	local values = Instance.new("StyleSheet")
	values.Name = "Values"
	local themeDerive = Instance.new("StyleDerive")
	themeDerive.Name = "ActiveTheme"
	themeDerive.Parent = values
	local densityDerive = Instance.new("StyleDerive")
	densityDerive.Name = "ActiveDensity"
	densityDerive.Parent = values
	values.Parent = folder
	self._themeDerive = themeDerive
	self._densityDerive = densityDerive
	self._values = values

	-- The layers, each deriving the one below: Lucy, the game, Lucy's fixed rules, then live rules
	-- on top (ADR 0052)
	self._layers = {}
	self._bands = { Lucy = {}, Game = {}, Fixed = {} }
	local below = values
	for _, name in { "Lucy", "Game", "Fixed", "Design" } do
		local sheet = Instance.new("StyleSheet")
		sheet.Name = name
		local derive = Instance.new("StyleDerive")
		derive.Name = below.Name
		derive.StyleSheet = below
		derive.Parent = sheet
		sheet.Parent = folder
		self._layers[name] = sheet
		below = sheet
	end
	self.design = self._layers.Design

	self:_applyTheme(pickDefault(themes, options.default, Tokens.defaultTheme))
	self:_applyDensity(pickDefault(densities, options.density, Tokens.defaultDensity))

	-- Lucy's layer, whole, before any gui links to it: the base rules, then every declared group
	if options.baseRules ~= false then
		self:addRules("uikit-base", Theme.baseRules, { layer = "lucy" })
	end
	for _, group in declared do
		self:addRules(group.key, group.rules, { layer = "lucy" })
	end

	folder.Parent = options.parent or ReplicatedStorage
	return self
end

function Theme._applyTheme(self: Theme, name: string)
	local sheet = self._themes[name]
	if not sheet then
		error(`[Lucy] unknown theme "{name}"`, 3)
	end
	self._current = name
	self._themeDerive.StyleSheet = sheet
end

function Theme._applyDensity(self: Theme, name: string)
	local sheet = self._densities[name]
	if not sheet then
		error(`[Lucy] unknown density "{name}"`, 3)
	end
	self._density = name
	self._densityDerive.StyleSheet = sheet
end

function Theme.get(self: Theme): string
	return self._current
end

function Theme.names(self: Theme): { string }
	local out = {}
	for name in self._themes do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

function Theme.set(self: Theme, name: string)
	if name == self._current then
		return
	end
	self:_applyTheme(name)
	self.Changed:Fire(name)
end

function Theme.getDensity(self: Theme): string
	return self._density
end

function Theme.setDensity(self: Theme, name: string)
	if name == self._density then
		return
	end
	self:_applyDensity(name)
	self.DensityChanged:Fire(name)
end

-- Each control height and the text it holds. ControlIcon holds an icon only.
local GROWS: { [string]: string } =
	{ ControlSm = "TextXs", ControlMd = "TextSm", ControlLg = "TextBase", ControlXl = "TextLg" }

--[[
	Grows control heights for larger text: each Control token gets what
	grow(size) returns for its text size, in every density. nil takes it off.
	App sets this from the player's text size (Core/Preferences).
]]
function Theme.setTextGrowth(self: Theme, grow: ((size: number) -> number)?)
	if grow == self._grow then
		return
	end
	self._grow = grow
	for name, values in self._densityValues do
		local sheet = self._densities[name]
		for control, text in GROWS do
			local base = values[control]
			local size = values[text]
			if typeof(base) == "UDim2" and type(size) == "number" then
				local add = if grow then math.max(0, math.round(grow(size))) else 0
				sheet:SetAttribute(control, base + UDim2.fromOffset(0, add))
			end
		end
	end
	self.MetricsChanged:Fire()
end

--[[
	Makes see-through backgrounds more solid: every number token whose name
	ends in Transparency (the modal scrim's OverlayTransparency) is multiplied
	by `scale`, in every theme. 0 is solid; nil puts the designed values back.
	App sets this from the player's background transparency (Core/Preferences).
]]
function Theme.setTransparency(self: Theme, scale: number?)
	local value = if scale == nil then 1 else math.clamp(scale, 0, 1)
	if value == self._transparency then
		return
	end
	self._transparency = value
	for name, tokens in self._seeThrough do
		local sheet = self._themes[name]
		for token, base in tokens do
			sheet:SetAttribute(token, base * value)
		end
	end
end

local function read(self, name: string): any
	local value = self._themes[self._current]:GetAttribute(name)
	if value == nil then
		value = self._densities[self._density]:GetAttribute(name)
	end
	if value == nil then
		value = self._tokens:GetAttribute(name)
	end
	return value
end

-- Resolves a token through aliases to the raw value currently in effect.
function Theme.resolve(self: Theme, token: string): any
	local value = read(self, token)
	local depth = 0
	while Tokens.isAlias(value) and depth < 16 do
		value = read(self, string.sub(value, 2))
		depth += 1
	end
	return value
end

-- Adds the Design StyleLink to a ScreenGui (only one sheet may apply per tree).
function Theme.link(self: Theme, gui: Instance): StyleLink
	local existing = gui:FindFirstChildOfClass("StyleLink")
	if existing then
		existing.StyleSheet = self.design
		return existing
	end
	local link = Instance.new("StyleLink")
	link.Name = "LucyStyleLink"
	link.StyleSheet = self.design
	link.Parent = gui
	return link
end

function Theme.hasRules(self: Theme, key: string): boolean
	return self._rules[key] ~= nil
end

--[[
	Adds a group of rules, once per key, to a layer: "game" (the default), "lucy" (Lucy's own) or
	"live" (rules added and removed while a game runs: a small sheet, so cheap to change). A rule
	with fixed = true goes to the Fixed layer, over the game's: for what a component is, not how it
	looks (Lucy's own; a game's look never needs it).
]]
function Theme.addRules(self: Theme, key: string, rules: { Rule }, options: { layer: string? }?)
	local layerName = options and options.layer or "game"
	local sheetName = LAYERS[layerName]
	if not sheetName then
		error(`[Lucy] addRules: unknown layer "{tostring(layerName)}" (lucy, game or live)`, 2)
	end
	if self._rules[key] then
		return
	end
	local created = {}
	local function make(name: string, rule: Rule, selector: string, properties: { [string]: any })
		local styleRule = Instance.new("StyleRule")
		styleRule.Name = name
		styleRule.Selector = selector
		styleRule.Priority = rule.priority or 0
		styleRule:SetProperties(properties)
		if rule.transitions then
			-- Transitions are newer API; never let them break a theme.
			pcall(function()
				styleRule:SetPropertyTransitions(rule.transitions)
			end)
		end
		styleRule.Parent = sheetFor(self, if rule.fixed then "Fixed" else sheetName, styleRule.Priority)
		if styleRule.SelectorError ~= "" then
			warn(`[Lucy] style selector "{selector}" ({key}) error: {styleRule.SelectorError}`)
		end
		table.insert(created, styleRule)
	end
	for index, rule in rules do
		if not usesColor(rule.properties) then
			-- Scoped with no $Color: one copy, for whatever is coloured (ui-colored)
			local selector = if rule.scoped
				then onFirstCompound(rule.selector, "ui-colored")
				else rule.selector
			make(`{key}_{index}`, rule, selector, rule.properties)
			continue
		end
		-- A rule in $Color (ADR 0052): Primary's copy for where no colour is set (unless scoped),
		-- then one copy per colour, each right after the one before so it wins a tie. A colour that
		-- names its groups is compiled only for those (ADR 0053)
		if not rule.scoped then
			make(`{key}_{index}`, rule, rule.selector, recolor(rule.properties, "Primary"))
		end
		local compounds = self._colorCompounds[key] or {}
		self._colorCompounds[key] = compounds
		for _, compound in firstCompounds(rule.selector) do
			table.insert(compounds, compound)
		end
		for _, name in self._colorNames do
			local only = self._colorGroups[name]
			if only and not only[key] then
				continue
			end
			make(
				`{key}_{index}_{name}`,
				rule,
				Theme.colorSelector(rule.selector, name),
				recolor(rule.properties, Theme.tokenOf(name))
			)
		end
	end
	self._rules[key] = created
end

-- A layer's rules in the order they apply: "lucy", "game", "fixed" or "live"
function Theme.rulesOf(self: Theme, layerName: string): { StyleRule }
	local name = if layerName == "fixed" then "Fixed" else LAYERS[layerName]
	local out = {}
	local function from(sheet: StyleSheet)
		for _, child in sheet:GetChildren() do
			if child:IsA("StyleRule") then
				table.insert(out, child)
			end
		end
	end
	local bands = self._bands[name]
	if not bands then
		from(self._layers[name])
		return out
	end
	local priorities = {}
	for priority in bands do
		table.insert(priorities, priority)
	end
	table.sort(priorities)
	for _, priority in priorities do
		from(bands[priority])
	end
	return out
end

-- The named colours, sorted (Primary, the colour where none is set, is not one of them)
function Theme.colors(self: Theme): { string }
	return table.clone(self._colorNames)
end

function Theme.removeRules(self: Theme, key: string)
	local created = self._rules[key]
	if not created then
		return
	end
	for _, rule in created do
		rule:Destroy()
	end
	self._rules[key] = nil
	self._colorCompounds[key] = nil
end

--[[
	The coloured elements under `root` (and root itself) that a group's $Color rule would style if
	their colour listed that group (ADR 0053): what a colour's `on` leaves out. A check for Studio
	and specs; Lucy does not run it by itself. Each entry: { instance, color, group }.
]]
function Theme.uncoveredColors(
	self: Theme,
	root: Instance
): { { instance: Instance, color: string, group: string } }
	local found = {}
	local keys = {}
	for key in self._colorCompounds do
		table.insert(keys, key)
	end
	table.sort(keys)
	local function check(instance: Instance)
		local colour: string? = nil
		for _, tag in instance:GetTags() do
			local name = string.match(tag, "^ui%-color%-(.+)$")
			if name then
				colour = name
			end
		end
		local only = colour and self._colorGroups[colour]
		if not only then
			return
		end
		for _, key in keys do
			if not only[key] then
				for _, compound in self._colorCompounds[key] do
					if matchesCompound(instance, compound) then
						table.insert(found, { instance = instance, color = colour :: string, group = key })
						break
					end
				end
			end
		end
	end
	check(root)
	for _, instance in root:GetDescendants() do
		check(instance)
	end
	return found
end

function Theme.destroy(self: Theme)
	self.Changed:DisconnectAll()
	self.DensityChanged:DisconnectAll()
	self.MetricsChanged:DisconnectAll()
	self.folder:Destroy()
	self._rules = {}
end

return Theme
