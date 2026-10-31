--!strict
--[[
	Theme: builds the Universal Styling sheet graph and switches themes (ADR 0003).

		Folder <name>
		├─ StyleSheet "Tokens"            attributes = primitives (palette, radius, space, fonts)
		├─ StyleSheet "Theme_light"       StyleDerive -> Tokens, attributes = semantic colours
		├─ StyleSheet "Theme_dark"        StyleDerive -> Tokens, attributes = semantic colours
		├─ StyleSheet "Density_default"   control heights + type scale
		├─ StyleSheet "Density_touch"
		├─ StyleSheet "Density_tv"
		└─ StyleSheet "Design"            StyleDerive -> active Theme_*, StyleDerive -> active Density_*,
		                                  plus every StyleRule (base rules + component rules)

	ScreenGuis get a StyleLink to "Design" (theme:link). Switching theme or density
	only re-points a StyleDerive on Design, so every linked gui restyles at once.

	Base rules (always present) take control of Roblox defaults inside linked guis:
	no default borders, no AutoButtonColor tinting, themed text, and our own
	focus ring (".ui-focus-visible") in place of the engine's selection image.

	Components contribute rules through theme:addRules(key, rules); a rule is
		{ selector = ".ui-button:Hover", priority = 20,
		  properties = { BackgroundColor3 = "$PrimaryHover" },
		  transitions = { BackgroundColor3 = TweenInfo.new(0.12) } }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(script.Parent.Signal)
local Tokens = require(script.Parent.Tokens)

local Theme = {}
Theme.__index = Theme

export type Rule = {
	selector: string,
	priority: number?,
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
		_rules: { [string]: { StyleRule } },
		_themes: { [string]: StyleSheet },
		_densities: { [string]: StyleSheet },
		_densityValues: { [string]: { [string]: any } },
		_grow: ((size: number) -> number)?,
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
	},
})

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
		setAttributes(sheet, Tokens.resolveTheme(values, primitives))
		sheet.Parent = folder
		self._themes[name] = sheet
	end

	for name, values in densities do
		local sheet = Instance.new("StyleSheet")
		sheet.Name = "Density_" .. name
		setAttributes(sheet, values)
		sheet.Parent = folder
		self._densities[name] = sheet
	end

	local design = Instance.new("StyleSheet")
	design.Name = "Design"
	local themeDerive = Instance.new("StyleDerive")
	themeDerive.Name = "ActiveTheme"
	themeDerive.Parent = design
	local densityDerive = Instance.new("StyleDerive")
	densityDerive.Name = "ActiveDensity"
	densityDerive.Parent = design
	design.Parent = folder
	self.design = design
	self._themeDerive = themeDerive
	self._densityDerive = densityDerive

	self:_applyTheme(pickDefault(themes, options.default, Tokens.defaultTheme))
	self:_applyDensity(pickDefault(densities, options.density, Tokens.defaultDensity))

	if options.baseRules ~= false then
		self:addRules("uikit-base", Theme.baseRules)
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
local GROWS: { [string]: string } = { ControlSm = "TextXs", ControlMd = "TextSm", ControlLg = "TextBase" }

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

function Theme.addRules(self: Theme, key: string, rules: { Rule })
	if self._rules[key] then
		return
	end
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
		styleRule.Parent = self.design
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
