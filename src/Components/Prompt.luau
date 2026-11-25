--!strict
--[[
	Prompt (ADR 0057): an interaction prompt in the world that replaces Roblox's
	ProximityPrompt with Lucy styling, device-aware key caps (Kbd), hold progress,
	nearest-prompt exclusivity and restyling for existing ProximityPrompts.

		Prompt.new({
			target = boothPart,              -- BasePart | Attachment | Model
			action = "interact",             -- Lucy Actions name (Kbd shows its key)
			actionText = "Play a set",
			objectText = "DJ Booth",
			distance = 10,                   -- studs
			hold = 0.6,                      -- hold seconds (0 for instant)
			exclusive = true,                -- only the nearest prompt for this action is live
			onTrigger = function(prompt) end,
		})

		Prompt.restyle(app, { variant = "overlay" }) -- restyle every ProximityPrompt in the game
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Floating = require(script.Parent.Parent.Core.Floating)
local Kbd = require(script.Parent.Kbd)
local Progress = require(script.Parent.Progress)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Signal = require(script.Parent.Parent.Core.Signal)
local Slot = require(script.Parent.Slot)
local Text = require(script.Parent.Text)
local Theme = require(script.Parent.Parent.Core.Theme)

local Prompt = {}

Prompt.variants = { "default", "inverse", "primary", "secondary", "outline", "destructive", "overlay" }
Prompt.sizes = { "sm", "md", "lg" }
Prompt.ringSizes = { sm = 28, md = 34, lg = 40 }
Prompt.kbdSizes = { sm = 20, md = 24, lg = 28 }

local BASE, VARIANT, STATE = 0, 10, 25

local rules: { Component.Rule } = {
	{
		selector = ".ui-prompt-body",
		priority = BASE,
		properties = {
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
			BorderSizePixel = 0,
		},
	},
	{
		selector = ".ui-prompt-body.ui-prompt-themed-fill",
		priority = BASE,
		properties = { BackgroundColor3 = "$Popover" },
	},
	{ selector = ".ui-prompt-body::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-prompt-body::UIPadding",
		priority = BASE,
		properties = {
			PaddingLeft = "$Space3",
			PaddingRight = "$Space3",
			PaddingTop = "$Space2",
			PaddingBottom = "$Space2",
		},
	},
	{
		selector = ".ui-prompt-stroke",
		priority = BASE,
		properties = {
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-prompt-stroke.ui-prompt-themed-stroke",
		priority = BASE,
		properties = { Color = "$Border" },
	},
	{
		selector = ".ui-prompt-object",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextXs",
		},
	},
	{
		selector = ".ui-prompt-track",
		priority = BASE,
		properties = { BackgroundColor3 = "$Secondary", BorderSizePixel = 0 },
	},
	{
		selector = ".ui-prompt-track::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusFull" },
	},
	{
		selector = ".ui-prompt-fill",
		priority = BASE,
		properties = { BackgroundColor3 = "$Color", BorderSizePixel = 0 },
	},
	{
		selector = ".ui-prompt-fill::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusFull" },
	},

	-- Variants
	{
		selector = ".ui-prompt-body.ui-prompt-variant-inverse",
		priority = VARIANT,
		properties = { TextColor3 = "$Background" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-inverse >> .ui-prompt-fill",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Background" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-inverse >> .ui-prompt-track",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$MutedForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-inverse >> .ui-progress-ring-stroke",
		priority = VARIANT + 5,
		properties = { Color = "$Background" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-inverse >> .ui-progress-ring-track",
		priority = VARIANT + 5,
		properties = { Color = "$MutedForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-themed-fill.ui-prompt-variant-inverse",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Foreground" },
	},
	{
		selector = ".ui-prompt-stroke.ui-prompt-themed-stroke.ui-prompt-variant-inverse",
		priority = VARIANT,
		properties = { Color = "$Foreground" },
	},

	{
		selector = ".ui-prompt-body.ui-prompt-variant-primary",
		priority = VARIANT,
		properties = { TextColor3 = "$ColorForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-primary >> .ui-prompt-fill",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$ColorForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-primary >> .ui-prompt-track",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$ColorHover" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-primary >> .ui-progress-ring-stroke",
		priority = VARIANT + 5,
		properties = { Color = "$ColorForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-primary >> .ui-progress-ring-track",
		priority = VARIANT + 5,
		properties = { Color = "$ColorHover" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-themed-fill.ui-prompt-variant-primary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Color" },
	},
	{
		selector = ".ui-prompt-stroke.ui-prompt-themed-stroke.ui-prompt-variant-primary",
		priority = VARIANT,
		properties = { Color = "$Color" },
	},

	{
		selector = ".ui-prompt-body.ui-prompt-variant-secondary",
		priority = VARIANT,
		properties = { TextColor3 = "$SecondaryForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-secondary >> .ui-progress-ring-track",
		priority = VARIANT + 5,
		properties = { Color = "$Border" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-themed-fill.ui-prompt-variant-secondary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Secondary" },
	},

	{
		selector = ".ui-prompt-body.ui-prompt-variant-outline",
		priority = VARIANT,
		properties = { TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-themed-fill.ui-prompt-variant-outline",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Background" },
	},

	{
		selector = ".ui-prompt-body.ui-prompt-variant-destructive",
		priority = VARIANT,
		properties = { TextColor3 = "$DestructiveForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-destructive >> .ui-prompt-fill",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$DestructiveForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-destructive >> .ui-prompt-track",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$DestructiveHover" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-destructive >> .ui-progress-ring-stroke",
		priority = VARIANT + 5,
		properties = { Color = "$DestructiveForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-destructive >> .ui-progress-ring-track",
		priority = VARIANT + 5,
		properties = { Color = "$DestructiveHover" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-themed-fill.ui-prompt-variant-destructive",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Destructive" },
	},
	{
		selector = ".ui-prompt-stroke.ui-prompt-themed-stroke.ui-prompt-variant-destructive",
		priority = VARIANT,
		properties = { Color = "$Destructive" },
	},

	{
		selector = ".ui-prompt-body.ui-prompt-variant-overlay",
		priority = VARIANT,
		properties = { TextColor3 = "$OverlayFillForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-overlay >> .ui-prompt-fill",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$OverlayFillForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-variant-overlay >> .ui-progress-ring-stroke",
		priority = VARIANT + 5,
		properties = { Color = "$OverlayFillForeground" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-themed-fill.ui-prompt-variant-overlay",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$OverlayFill" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-themed-alpha.ui-prompt-variant-overlay",
		priority = VARIANT,
		properties = { BackgroundTransparency = "$OverlayFillTransparency" },
	},

	-- Border overrides
	{
		selector = ".ui-prompt-stroke.ui-prompt-border",
		priority = STATE,
		properties = { Thickness = "$StrokeThin", Transparency = 0 },
	},
	{
		selector = ".ui-prompt-stroke.ui-prompt-no-border",
		priority = STATE,
		properties = { Thickness = 0, Transparency = 1 },
	},

	-- Dimmed when another nearer exclusive prompt holds the action
	{
		selector = ".ui-prompt-body.ui-prompt-inactive",
		priority = STATE,
		properties = { BackgroundTransparency = 0.45 },
	},

	-- Sizes
	{
		selector = ".ui-prompt-body.ui-prompt-size-sm",
		priority = VARIANT,
		properties = { TextSize = "$TextXs" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-size-sm::UIPadding",
		priority = VARIANT,
		properties = {
			PaddingLeft = "$Space2",
			PaddingRight = "$Space2",
			PaddingTop = "$Space1",
			PaddingBottom = "$Space1",
		},
	},
	{
		selector = ".ui-prompt-body.ui-prompt-size-lg",
		priority = VARIANT,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-prompt-body.ui-prompt-size-lg::UIPadding",
		priority = VARIANT,
		properties = {
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
			PaddingTop = "$Space3",
			PaddingBottom = "$Space3",
		},
	},
}
Prompt.rules = rules
for _, rule in Slot.flow(rules) do
	table.insert(Prompt.rules, rule)
end
for _, rule in Slot.rules do
	table.insert(Prompt.rules, rule)
end

local extraVariants: { { key: string, rules: { Component.Rule } } } = {}

local function checkVariant(variant: string)
	if not table.find(Prompt.variants, variant) then
		error(`[Lucy] unknown Prompt variant "{tostring(variant)}"`, 0)
	end
end

local function checkSize(size: string)
	if not table.find(Prompt.sizes, size) then
		error(`[Lucy] unknown Prompt size "{tostring(size)}" (expected sm, md or lg)`, 0)
	end
end

local function splitRuleProps(
	props: { [string]: any },
	keys: { string }
): ({ [string]: any }, { [string]: any })
	local picked: { [string]: any } = {}
	local rest: { [string]: any } = {}
	local set: { [string]: boolean } = {}
	for _, k in keys do
		set[k] = true
	end
	for k, v in props do
		if set[k] then
			picked[k] = v
		else
			rest[k] = v
		end
	end
	return picked, rest
end

-- Registers a custom Prompt variant (ADR 0022).
function Prompt.addVariant(name: string, variantRules: { Component.Rule })
	if type(name) ~= "string" or name == "" then
		error("[Lucy] Prompt.addVariant needs a variant name", 2)
	end
	if not table.find(Prompt.variants, name) then
		table.insert(Prompt.variants, name)
	end
	local key = "prompt-variant-" .. name
	local compiled: { Component.Rule } = {}
	for _, rule in variantRules do
		local sel = rule.selector or ""
		local priority = rule.priority or VARIANT
		if sel == "" then
			local special, rest =
				splitRuleProps(rule.properties, { "BackgroundColor3", "BackgroundTransparency" })
			if next(rest) ~= nil then
				table.insert(compiled, {
					selector = `.ui-prompt-body.ui-prompt-variant-{name}`,
					priority = priority,
					properties = rest,
					transitions = rule.transitions,
				})
			end
			if special.BackgroundColor3 ~= nil then
				table.insert(compiled, {
					selector = `.ui-prompt-body.ui-prompt-themed-fill.ui-prompt-variant-{name}`,
					priority = priority,
					properties = { BackgroundColor3 = special.BackgroundColor3 },
					transitions = rule.transitions,
				})
			end
			if special.BackgroundTransparency ~= nil then
				table.insert(compiled, {
					selector = `.ui-prompt-body.ui-prompt-themed-alpha.ui-prompt-variant-{name}`,
					priority = priority,
					properties = { BackgroundTransparency = special.BackgroundTransparency },
					transitions = rule.transitions,
				})
			end
		elseif sel == "::UIStroke" then
			local colorOnly, strokeRest = splitRuleProps(rule.properties, { "Color" })
			if next(strokeRest) ~= nil then
				table.insert(compiled, {
					selector = `.ui-prompt-stroke.ui-prompt-variant-{name}`,
					priority = priority,
					properties = strokeRest,
				})
			end
			if colorOnly.Color ~= nil then
				table.insert(compiled, {
					selector = `.ui-prompt-stroke.ui-prompt-themed-stroke.ui-prompt-variant-{name}`,
					priority = priority,
					properties = colorOnly,
				})
			end
		else
			table.insert(compiled, {
				selector = `.ui-prompt-body.ui-prompt-variant-{name}{sel}`,
				priority = priority,
				properties = rule.properties,
				transitions = rule.transitions,
			})
		end
	end
	for _, twin in Slot.flow(compiled) do
		table.insert(compiled, twin)
	end
	table.insert(extraVariants, { key = key, rules = compiled })
	Theme.declare(key, compiled)
end

type PromptEntry = {
	id: string,
	groupKey: () -> string,
	inRange: () -> boolean,
	distance: () -> number,
	enabled: () -> boolean,
	exclusive: boolean,
	active: Reactive.Ref<boolean>,
}

local function registryOf(app: any): { PromptEntry }
	local list = app._lucyPrompts
	if not list then
		list = {}
		app._lucyPrompts = list
	end
	return list
end

local function resolveExclusive(app: any)
	local list = registryOf(app)
	local winners: { [string]: { entry: PromptEntry, dist: number } } = {}
	for _, entry in list do
		local inRange: boolean = (Reactive.peek(entry.inRange :: any) :: any) == true
		local enabled: boolean = (Reactive.peek(entry.enabled :: any) :: any) == true
		if entry.exclusive and inRange and enabled then
			local key = entry.groupKey()
			local d: number = Reactive.peek(entry.distance :: any) :: any
			local best = winners[key]
			if best == nil or d < best.dist then
				winners[key] = { entry = entry, dist = d }
			end
		end
	end
	for _, entry in list do
		if entry.exclusive then
			local best = winners[entry.groupKey()]
			entry.active(best ~= nil and best.entry == entry)
		else
			local inRange: boolean = (Reactive.peek(entry.inRange :: any) :: any) == true
			local enabled: boolean = (Reactive.peek(entry.enabled :: any) :: any) == true
			entry.active(inRange and enabled)
		end
	end
end

local function resolveColorValue(app: any, themeTick: () -> number, raw: any): Color3?
	if raw == nil then
		return nil
	end
	local value = Reactive.toValue(raw)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		themeTick()
		local token = string.gsub(value, "^%$", "")
		local resolved = app.theme:resolve(token)
		if typeof(resolved) == "Color3" then
			return resolved
		end
	end
	return nil
end

local function resolveUDimValue(app: any, themeTick: () -> number, raw: any): UDim?
	local value = Reactive.toValue(raw)
	if typeof(value) == "UDim" then
		return value
	elseif type(value) == "number" then
		return UDim.new(0, value)
	elseif type(value) == "string" then
		themeTick()
		local token = string.gsub(value, "^%$", "")
		local resolved = app.theme:resolve(token)
		if typeof(resolved) == "UDim" then
			return resolved
		end
	end
	return nil
end

local function keyMatches(expected: any, code: Enum.KeyCode): boolean
	if typeof(expected) == "EnumItem" then
		return expected == code
	elseif type(expected) == "string" and expected ~= "" then
		return code.Name == expected
	end
	return false
end

local spec: Component.Spec = {
	kind = "prompt",
	defaults = {
		action = "",
		keyboard = "",
		gamepad = "",
		touch = "",
		actionText = "Interact",
		objectText = "",
		distance = 10,
		hold = 0,
		enabled = true,
		variant = "default",
		size = "md",
		side = "top",
		align = "center",
		open = false,
		visible = true,
	},
	rules = Prompt.rules,
	render = function(h)
		local p: Component.Props = h.props
		checkVariant(h:get("variant"))
		checkSize(h:get("size"))

		for _, extra in extraVariants do
			if not h.app.theme:hasRules(extra.key) then
				h.app.theme:addRules(extra.key, extra.rules, { layer = "game" })
			end
		end

		local actionRef = h:ref("action")
		local keyboardRef = h:ref("keyboard")
		local gamepadRef = h:ref("gamepad")
		local touchRef = h:ref("touch")
		local actionTextRef = h:ref("actionText")
		local objectTextRef = h:ref("objectText")
		local distanceRef = h:ref("distance")
		local holdRef = h:ref("hold")
		local enabledRef = h:ref("enabled")
		local variant = h:ref("variant")
		local size = h:ref("size")
		local sideRef = h:ref("side")
		local alignRef = h:ref("align")
		local openRef = h:ref("open")
		local visibleRef = h:ref("visible")

		local triggered = Signal.new()
		local holdBegan = Signal.new()
		local holdEnded = Signal.new()
		h.Triggered = triggered
		h.HoldBegan = holdBegan
		h.HoldEnded = holdEnded
		Reactive.onCleanup(function()
			triggered:DisconnectAll()
			holdBegan:DisconnectAll()
			holdEnded:DisconnectAll()
		end)

		local themeTick = Reactive.ref(0)
		local themeConn = h.app.theme.Changed:Connect(function()
			themeTick(themeTick() + 1)
		end)
		Reactive.onCleanup(function()
			themeConn:Disconnect()
		end)

		local function borderTag(): string?
			local b = Reactive.toValue(p.border)
			if b == false then
				return "ui-prompt-no-border"
			elseif b == true or type(b) == "string" or typeof(b) == "Color3" or p.stroke ~= nil then
				return "ui-prompt-border"
			end
			return nil
		end

		local function variantTag(): string
			local v = variant()
			checkVariant(v)
			return "ui-prompt-variant-" .. v
		end

		local rawTarget = p.target or p.reference
		local resolvedTarget = rawTarget
		if type(resolvedTarget) == "function" then
			resolvedTarget = resolvedTarget()
		end
		if type(resolvedTarget) == "table" and resolvedTarget.Instance then
			resolvedTarget = resolvedTarget.Instance
		end
		local isWorldTarget = typeof(resolvedTarget) == "Instance"
			and (
				resolvedTarget:IsA("BasePart")
				or resolvedTarget:IsA("Attachment")
				or resolvedTarget:IsA("Model")
			)
		local isVectorTarget = typeof(resolvedTarget) == "Vector3"
		local inlineMode = rawTarget == nil
		local manual = p.manual == true or (not isWorldTarget and not isVectorTarget)
		local exclusive = p.exclusive ~= false
		local showWhenInactive = p.showWhenInactive == true

		local inRangeRef = Reactive.ref(manual)
		local distRef = Reactive.ref(0)
		local activeRef = Reactive.ref(manual and Reactive.peek(enabledRef) == true)

		local proximity: Composables.Proximity? = nil
		if not manual then
			local prox = Composables.useProximity(h.app, rawTarget, {
				distance = distanceRef,
				hysteresis = p.hysteresis or 0.5,
				lineOfSight = p.lineOfSight,
				origin = p.origin,
			})
			proximity = prox
			inRangeRef = prox.active :: any
			distRef = prox.distance :: any
		end

		local entry: PromptEntry = {
			id = h.id,
			groupKey = function(): string
				local act = Reactive.peek(actionRef)
				if type(act) == "string" and act ~= "" then
					return "action:" .. act
				end
				return "key:"
					.. tostring(Reactive.peek(keyboardRef))
					.. ":"
					.. tostring(Reactive.peek(gamepadRef))
			end,
			inRange = inRangeRef,
			distance = distRef,
			enabled = enabledRef,
			exclusive = exclusive,
			active = activeRef,
		}

		if not manual then
			local list = registryOf(h.app)
			table.insert(list, entry)
			Reactive.watchEffect(function()
				local _ = inRangeRef()
				local _2 = distRef()
				local _3 = enabledRef()
				local _4 = actionRef()
				Reactive.untrack(resolveExclusive, h.app)
			end)
			Reactive.onCleanup(function()
				local idx = table.find(list, entry)
				if idx then
					table.remove(list, idx)
				end
				resolveExclusive(h.app)
			end)
		else
			Reactive.watchEffect(function()
				activeRef(enabledRef() == true)
			end)
		end

		Reactive.watchEffect(function()
			local shown = if showWhenInactive then inRangeRef() and enabledRef() == true else activeRef()
			openRef(shown)
		end)

		local holdingRef = Reactive.ref(false)
		local initialProgress = if p.progress ~= nil then Reactive.toValue(p.progress) else 0
		local progressRef = Reactive.ref(if type(initialProgress) == "number" then initialProgress else 0)
		if p.progress ~= nil and type(p.progress) == "function" then
			Reactive.watchEffect(function()
				if not Reactive.peek(holdingRef) then
					local v = Reactive.toValue(p.progress)
					progressRef(if type(v) == "number" then v else 0)
				end
			end)
		end

		local strokeColorSource = if type(p.border) == "string" or typeof(p.border) == "Color3"
			then p.border
			else p.stroke
		local themedFillTag = if p.fill == nil then "ui-prompt-themed-fill" else nil
		local themedAlphaTag = if p.transparency == nil then "ui-prompt-themed-alpha" else nil
		local themedStrokeTag = if strokeColorSource == nil then "ui-prompt-themed-stroke" else nil

		local strokeProps: { [string]: any } = {
			Name = "Stroke",
			Tags = { "ui-prompt-stroke" :: any, variantTag, borderTag, themedStrokeTag },
		}
		if strokeColorSource ~= nil then
			strokeProps.Color = function(): Color3
				return resolveColorValue(h.app, themeTick, strokeColorSource) or Color3.new(1, 1, 1)
			end
		end
		if p.strokeThickness ~= nil then
			strokeProps.Thickness = p.strokeThickness
		end
		local stroke = Element.new("UIStroke", strokeProps) :: UIStroke
		h.stroke = stroke

		local bodyProps: { [any]: any } = {
			Name = "Body",
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			Active = true,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			ZIndex = 2,
			Tags = {
				"ui-prompt-body" :: any,
				variantTag,
				borderTag,
				themedFillTag,
				themedAlphaTag,
				function(): string
					local s = size()
					checkSize(s)
					return "ui-prompt-size-" .. s
				end,
				["ui-prompt-inactive"] = function(): boolean
					return not activeRef()
				end,
			},
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
			}),
			stroke,
		}
		if p.fill ~= nil then
			bodyProps.BackgroundColor3 = function(): Color3
				return resolveColorValue(h.app, themeTick, p.fill) or Color3.new(1, 1, 1)
			end
		end
		if p.transparency ~= nil then
			bodyProps.BackgroundTransparency = p.transparency
		end
		if p.radius ~= nil then
			table.insert(
				bodyProps,
				Element.new("UICorner", {
					CornerRadius = function(): UDim
						return resolveUDimValue(h.app, themeTick, p.radius) or UDim.new(0, 8)
					end,
				})
			)
		end

		local body = Element.new("TextButton", bodyProps) :: TextButton
		h.body = body

		local row = Element.new("Frame", {
			Name = "Row",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			}),
		}) :: Frame
		row.Parent = body

		local function showRing(): boolean
			return (holdRef() or 0) > 0 or progressRef() > 0
		end

		local kbd = Kbd.new({
			app = h.app,
			action = actionRef,
			keyboard = keyboardRef,
			gamepad = gamepadRef,
			shape = "circle",
			size = function(): number
				return Prompt.kbdSizes[size()] or 24
			end,
			touch = function(): any
				local t = touchRef()
				if t ~= "" and t ~= nil then
					return t
				end
				return if (holdRef() or 0) > 0 then "Hold" else "Tap"
			end,
		})
		h.kbd = kbd

		local progressRing = Progress.new({
			app = h.app,
			shape = "circle",
			size = function(): number
				local s = size()
				if showRing() then
					return Prompt.ringSizes[s] or 34
				end
				return Prompt.kbdSizes[s] or 24
			end,
			value = progressRef,
			max = 1,
			trackVisible = showRing,
			visible = function(): boolean
				return kbd.Instance.Visible
			end,
			layoutOrder = 1,
			children = { kbd },
			Parent = row,
		})
		h.progressRing = progressRing
		h.progressBar = progressRing

		local labels = Element.new("Frame", {
			Name = "Labels",
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 1),
			}),
		}) :: Frame
		labels.Parent = row

		local objectLabel = Text.new({
			app = h.app,
			text = objectTextRef,
			autoWidth = true,
			name = "ObjectText",
			layoutOrder = 1,
			visible = function(): boolean
				return objectTextRef() ~= ""
			end,
		})
		objectLabel.Instance:AddTag("ui-prompt-object")
		objectLabel.Instance.Parent = labels
		h.objectLabel = objectLabel

		local actionLabel = Text.new({
			app = h.app,
			text = actionTextRef,
			autoWidth = true,
			name = "ActionText",
			layoutOrder = 2,
			visible = function(): boolean
				return actionTextRef() ~= ""
			end,
		})
		actionLabel.Instance:AddTag(Slot.TEXT_TAG)
		actionLabel.Instance.Parent = labels
		h.actionLabel = actionLabel

		local order = 2
		if p.content ~= nil then
			if type(p.content) == "function" then
				local built = p.content(h)
				if built ~= nil then
					order = Slot.fill(row, built, { app = h.app, startOrder = order })
				end
			else
				order = Slot.fill(row, p.content, { app = h.app, startOrder = order })
			end
		end
		if p.children ~= nil then
			Slot.fill(row, p.children, { app = h.app, startOrder = order })
		end

		local root = Element.new("Frame", {
			Name = "Prompt",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Visible = function(): boolean
				return openRef() and visibleRef()
			end,
			body,
		}) :: Frame

		local floating: Floating.FloatingHandle
		if inlineMode then
			floating = {
				world = false,
				gui = nil,
				overlay = nil,
				side = function(): string
					return sideRef()
				end,
				arrowOffset = function(): number
					return math.floor(body.AbsoluteSize.X / 2 + 0.5)
				end,
				arrowCenter = function(): number
					return 0
				end,
				visible = function(): boolean
					return openRef() and visibleRef()
				end,
				place = function() end,
			}
		else
			floating = Floating.use(h.app, {
				reference = rawTarget,
				content = root,
				open = function(): boolean
					return openRef() and visibleRef()
				end,
				side = sideRef,
				align = alignRef,
				studsOffset = p.studsOffset,
				maxDistance = p.maxDistance,
				alwaysOnTop = p.alwaysOnTop,
				name = "PromptBillboard",
			})
		end
		h.floating = floating

		-- Hold & trigger mechanics
		local holdConn: RBXScriptConnection? = nil
		local function stopHoldConn()
			if holdConn then
				holdConn:Disconnect()
				holdConn = nil
			end
		end
		Reactive.onCleanup(stopHoldConn)

		local function trigger()
			if h.destroyed then
				return
			end
			if p.onTrigger then
				p.onTrigger(h)
			end
			triggered:Fire(h)
			h:emit("activate")
		end

		local function endHold(completed: boolean?)
			if not Reactive.peek(holdingRef) then
				return
			end
			stopHoldConn()
			holdingRef(false)
			progressRef(0)
			local done = completed == true
			if p.onHoldEnd then
				p.onHoldEnd(h, done)
			end
			holdEnded:Fire(h, done)
		end

		local function stepHold(dt: number)
			if not Reactive.peek(holdingRef) or h.destroyed then
				return
			end
			local duration = Reactive.peek(holdRef) or 0
			if duration <= 0 then
				endHold(true)
				if not p._driven then
					trigger()
				end
				return
			end
			local nextProgress = math.min(1, Reactive.peek(progressRef) + dt / duration)
			progressRef(nextProgress)
			if nextProgress >= 1 then
				endHold(true)
				if not p._driven then
					trigger()
				end
			end
		end

		local function beginHold()
			if h.destroyed or not Reactive.peek(activeRef) then
				return
			end
			local duration = Reactive.peek(holdRef) or 0
			if duration <= 0 then
				if not p._driven then
					trigger()
				end
				return
			end
			if Reactive.peek(holdingRef) then
				return
			end
			holdingRef(true)
			progressRef(0)
			if p.onHoldBegin then
				p.onHoldBegin(h)
			end
			holdBegan:Fire(h)
			if RunService:IsRunning() and holdConn == nil then
				holdConn = RunService.Heartbeat:Connect(stepHold)
			end
		end

		Reactive.watch(activeRef, function(isActive)
			if not isActive then
				endHold(false)
			end
		end)

		if not p._driven then
			-- Listen to action or raw keycode while active
			Composables.useWhile(function(): boolean
				return activeRef() and not h.destroyed
			end, function()
				local act = actionRef()
				if type(act) == "string" and act ~= "" then
					local stopPress = h.app.actions:on(act, beginHold)
					local stopRelease = h.app.actions:onRelease(act, function()
						endHold(false)
					end)
					return function()
						stopPress()
						stopRelease()
					end
				end
				local kb = keyboardRef()
				local gp = gamepadRef()
				local began = UserInputService.InputBegan:Connect(
					function(input: InputObject, processed: boolean)
						if processed then
							return
						end
						if keyMatches(kb, input.KeyCode) or keyMatches(gp, input.KeyCode) then
							beginHold()
						end
					end
				)
				local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
					if keyMatches(kb, input.KeyCode) or keyMatches(gp, input.KeyCode) then
						endHold(false)
					end
				end)
				return function()
					began:Disconnect()
					ended:Disconnect()
				end
			end)

			-- Click / touch directly on the prompt pill
			local pointerDown = false
			local pillIn = body.InputBegan:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
					pointerDown = true
					beginHold()
				end
			end)
			local pillOut = UserInputService.InputEnded:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if
					pointerDown
					and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)
				then
					pointerDown = false
					endHold(false)
				end
			end)
			Reactive.onCleanup(function()
				pillIn:Disconnect()
				pillOut:Disconnect()
			end)
		end

		h.active = function(): boolean
			return activeRef()
		end
		h.inRange = function(): boolean
			return inRangeRef()
		end
		h.holding = function(): boolean
			return holdingRef()
		end
		h.progress = function(): number
			return progressRef()
		end
		function h:check()
			if proximity then
				proximity.check()
				resolveExclusive(h.app)
			end
		end
		function h:beginHold()
			beginHold()
		end
		function h:stepHold(dt: number)
			stepHold(dt)
		end
		function h:endHold()
			endHold(false)
		end
		function h:trigger()
			trigger()
		end

		return root
	end,
}

function Prompt.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

-- Restyles one existing Roblox ProximityPrompt instance with Lucy's Prompt.
function Prompt.restyleOne(
	app: any,
	raw: ProximityPrompt,
	options: { [string]: any }?
): (Component.Handle, () -> ())
	raw.Style = Enum.ProximityPromptStyle.Custom
	local props: { [string]: any } = table.clone(options or {})
	props.app = app
	props.target = raw.Parent
	props.manual = true
	props._driven = true
	props.open = true
	props.actionText = raw.ActionText
	props.objectText = raw.ObjectText
	props.keyboard = raw.KeyboardKeyCode
	props.gamepad = raw.GamepadKeyCode
	props.hold = raw.HoldDuration
	props.distance = raw.MaxActivationDistance
	props.enabled = raw.Enabled

	local prompt = Prompt.new(props)
	local connections: { RBXScriptConnection } = {}
	local function mirror(prop: string, key: string)
		table.insert(
			connections,
			raw:GetPropertyChangedSignal(prop):Connect(function()
				if not prompt.destroyed then
					prompt:set(key, (raw :: any)[prop])
				end
			end)
		)
	end
	mirror("ActionText", "actionText")
	mirror("ObjectText", "objectText")
	mirror("KeyboardKeyCode", "keyboard")
	mirror("GamepadKeyCode", "gamepad")
	mirror("HoldDuration", "hold")
	mirror("MaxActivationDistance", "distance")
	mirror("Enabled", "enabled")

	table.insert(
		connections,
		raw.PromptButtonHoldBegan:Connect(function()
			prompt:beginHold()
		end)
	)
	table.insert(
		connections,
		raw.PromptButtonHoldEnded:Connect(function()
			prompt:endHold()
		end)
	)
	table.insert(
		connections,
		raw.Triggered:Connect(function()
			if not prompt.destroyed then
				prompt.Triggered:Fire(prompt)
			end
		end)
	)

	local pointerDown = false
	table.insert(
		connections,
		prompt.body.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				pointerDown = true
				raw:InputHoldBegin()
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if
				pointerDown and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)
			then
				pointerDown = false
				raw:InputHoldEnd()
			end
		end)
	)

	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		if not prompt.destroyed then
			prompt:destroy()
		end
	end
	table.insert(connections, raw.Destroying:Connect(stop))
	return prompt, stop
end

-- Restyles every Roblox ProximityPrompt in the game using ProximityPromptService.
function Prompt.restyle(app: any, options: { [string]: any }?): () -> ()
	local active: { [ProximityPrompt]: () -> () } = {}
	local function applyCustom(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			instance.Style = Enum.ProximityPromptStyle.Custom
		end
	end
	for _, item in workspace:GetDescendants() do
		applyCustom(item)
	end
	local addedConn = workspace.DescendantAdded:Connect(applyCustom)
	local shownConn = ProximityPromptService.PromptShown:Connect(function(raw: ProximityPrompt)
		if active[raw] then
			return
		end
		local _, stop = Prompt.restyleOne(app, raw, options)
		active[raw] = stop
	end)
	local hiddenConn = ProximityPromptService.PromptHidden:Connect(function(raw: ProximityPrompt)
		local stop = active[raw]
		if stop then
			active[raw] = nil
			stop()
		end
	end)

	local function stopAll()
		addedConn:Disconnect()
		shownConn:Disconnect()
		hiddenConn:Disconnect()
		for raw, stop in active do
			active[raw] = nil
			stop()
		end
	end
	app.maid:give(stopAll)
	return stopAll
end

Component.define(spec)

return Prompt
