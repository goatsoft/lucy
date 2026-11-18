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
		└─ StyleSheet "Design"            StyleDerive -> Fixed; live rules (added and removed in play)

	The layers (ADR 0052): a sheet's own rules beat every rule of the sheet it derives, whatever
	their Priority, so a game's rule beats Lucy's look, Lucy's fixed rules beat the game's (a
	picture that keeps its own colours is not a look to restyle), and a live rule beats all.
	Priority orders rules within a layer, and at equal Priority the rule added later wins. Each
	layer is a sheet of its own because adding a rule costs in proportion to the rules already in
	that sheet.

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
-- Our focus ring, shown for keyboard and gamepad navigation (see InputManager).
table.insert(Theme.baseRules, {
	selector = ".ui-focus-visible::UIStroke",
	priority = FOCUS,
	properties = {
		Color = "$Ring",
		Thickness = "$FocusRing",
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		-- Inside the edge, so a ring never spills past its element or gets clipped.
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
	},
})

-- Rows that ring one part instead (Component.partRing): the row's own ring is
-- hidden and the part's ring shows.
table.insert(Theme.baseRules, {
	selector = ".ui-ring-host.ui-focus-visible::UIStroke",
	priority = FOCUS + 1,
	properties = { Transparency = 1 },
})
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
	local themes = options.themes or Tokens.themes
	local densities = options.densities or Tokens.densities
	validateSets(themes, "theme")
	validateSets(densities, "density")

	-- Fields are filled in below, once the instances they point at exist.
	local self: Theme = setmetatable({} :: any, Theme)
	self.Changed = Signal.new()
	self.DensityChanged = Signal.new()
	self.MetricsChanged = Signal.new()
	self._densityValues = densities
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

	-- The layers, each deriving the one below: Lucy, the game, Lucy's fixed rules, then live rules
	-- on top (ADR 0052)
	self._layers = {}
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
	local layer = self._layers[sheetName]
	local created = {}
	for index, rule in rules do
		local styleRule = Instance.new("StyleRule")
		styleRule.Name = `{key}_{index}`
		styleRule.Selector = rule.selector
		styleRule.Priority = rule.priority or 0
		styleRule:SetProperties(rule.properties)
		if rule.transitions then
			-- Transitions are newer API; never let them break a theme.
			pcall(function()
				styleRule:SetPropertyTransitions(rule.transitions)
			end)
		end
		styleRule.Parent = if rule.fixed then self._layers.Fixed else layer
		if styleRule.SelectorError ~= "" then
			warn(`[Lucy] style selector "{rule.selector}" ({key}) error: {styleRule.SelectorError}`)
		end
		table.insert(created, styleRule)
	end
	self._rules[key] = created
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
end

function Theme.destroy(self: Theme)
	self.Changed:DisconnectAll()
	self.DensityChanged:DisconnectAll()
	self.MetricsChanged:DisconnectAll()
	self.folder:Destroy()
	self._rules = {}
end

return Theme
