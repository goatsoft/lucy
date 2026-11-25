--!strict
--[[
	Tooltip (ADR 0057): a floating label or card attached to a screen control or a part
	in the world.

		Tooltip.new({
			target = buyButton,              -- GuiObject | BasePart | Attachment | Model | handle | id
			text = "Buy for 100 coins",      -- rendered with Lucy.Text
			textProps = { richText = true }, -- any Lucy.Text option
			children = { ... },              -- or content: any Lucy component inside
			trigger = "hover",               -- hover | focus | press | hold | click | toggle | always | proximity | manual
			distance = 12,                   -- proximity distance in studs
			side = "top",                    -- top | bottom | left | right | auto
			align = "center",                -- start | center | end
			placement = nil,                 -- shorthand like "top-start"
			offset = 8,                      -- pixels on screen (studsOffset in the world)
			arrow = true,                    -- show directional pointer toward target
			variant = "default",             -- default | inverse | primary | secondary | outline | destructive | overlay | registered
			size = "md",                     -- sm | md | lg
			border = nil,                    -- true | false | "$Token" | Color3
			fill = nil,                      -- "$Token" | Color3
			transparency = nil,              -- 0..1
			interactive = false,             -- let the pointer cross onto the tooltip
			open = nil,                      -- boolean or two-way ref
			onOpenChange = function(open, tip) end,
		})
		tip:show()  tip:hide()  tip:toggle()
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Floating = require(script.Parent.Parent.Core.Floating)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Slot = require(script.Parent.Slot)
local Text = require(script.Parent.Text)
local Theme = require(script.Parent.Parent.Core.Theme)

local Tooltip = {}

Tooltip.variants = { "default", "inverse", "primary", "secondary", "outline", "destructive", "overlay" }
Tooltip.sizes = { "sm", "md", "lg" }
Tooltip.triggers = { "hover", "focus", "press", "hold", "click", "toggle", "always", "proximity", "manual" }
Tooltip.arrowSize = 10
Tooltip.defaultMaxWidth = 260
Tooltip.defaultDelay = 0.4
Tooltip.defaultCloseDelay = 0.1
Tooltip.defaultLongPress = 0.45

local BASE, VARIANT, STATE = 0, 10, 25

local ARROW_DIR: { [string]: string } = {
	top = "down",
	bottom = "up",
	left = "right",
	right = "left",
}
local ARROW_GRAD_ROT: { [string]: number } = {
	top = 45,
	bottom = -135,
	left = -45,
	right = 135,
}
local ARROW_STROKE_CUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.501, 0),
	NumberSequenceKeypoint.new(1, 0),
})
local ARROW_FILL_SOLID_CUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.43, 1),
	NumberSequenceKeypoint.new(0.44, 0),
	NumberSequenceKeypoint.new(1, 0),
})

local rules: { Component.Rule } = {
	{
		selector = ".ui-tooltip-body",
		priority = BASE,
		properties = {
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
			BorderSizePixel = 0,
		},
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-themed-fill",
		priority = BASE,
		properties = { BackgroundColor3 = "$Popover" },
	},
	{ selector = ".ui-tooltip-body::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-tooltip-body::UIPadding",
		priority = BASE,
		properties = {
			PaddingLeft = "$Space3",
			PaddingRight = "$Space3",
			PaddingTop = "$Space1",
			PaddingBottom = "$Space1",
		},
	},
	{
		selector = ".ui-tooltip-stroke",
		priority = BASE,
		properties = {
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-tooltip-stroke.ui-tooltip-themed-stroke",
		priority = BASE,
		properties = { Color = "$Border" },
	},
	{
		selector = ".ui-tooltip-arrow",
		priority = BASE,
		properties = { BorderSizePixel = 0 },
	},
	{
		selector = ".ui-tooltip-arrow.ui-tooltip-themed-fill",
		priority = BASE,
		properties = { BackgroundColor3 = "$Popover" },
	},
	{
		selector = ".ui-tooltip-arrow-stroke",
		priority = BASE,
		properties = {
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-tooltip-arrow-stroke.ui-tooltip-themed-stroke",
		priority = BASE,
		properties = { Color = "$Border" },
	},

	-- Variants
	{
		selector = ".ui-tooltip-body.ui-tooltip-variant-inverse",
		priority = VARIANT,
		properties = { TextColor3 = "$Background" },
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-themed-fill.ui-tooltip-variant-inverse",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Foreground" },
	},
	{
		selector = ".ui-tooltip-arrow.ui-tooltip-themed-fill.ui-tooltip-variant-inverse",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Foreground" },
	},
	{
		selector = ".ui-tooltip-stroke.ui-tooltip-themed-stroke.ui-tooltip-variant-inverse",
		priority = VARIANT,
		properties = { Color = "$Foreground" },
	},
	{
		selector = ".ui-tooltip-arrow-stroke.ui-tooltip-themed-stroke.ui-tooltip-variant-inverse",
		priority = VARIANT,
		properties = { Color = "$Foreground" },
	},

	{
		selector = ".ui-tooltip-body.ui-tooltip-variant-primary",
		priority = VARIANT,
		properties = { TextColor3 = "$ColorForeground" },
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-themed-fill.ui-tooltip-variant-primary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Color" },
	},
	{
		selector = ".ui-tooltip-arrow.ui-tooltip-themed-fill.ui-tooltip-variant-primary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Color" },
	},
	{
		selector = ".ui-tooltip-stroke.ui-tooltip-themed-stroke.ui-tooltip-variant-primary",
		priority = VARIANT,
		properties = { Color = "$Color" },
	},
	{
		selector = ".ui-tooltip-arrow-stroke.ui-tooltip-themed-stroke.ui-tooltip-variant-primary",
		priority = VARIANT,
		properties = { Color = "$Color" },
	},

	{
		selector = ".ui-tooltip-body.ui-tooltip-variant-secondary",
		priority = VARIANT,
		properties = { TextColor3 = "$SecondaryForeground" },
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-themed-fill.ui-tooltip-variant-secondary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Secondary" },
	},
	{
		selector = ".ui-tooltip-arrow.ui-tooltip-themed-fill.ui-tooltip-variant-secondary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Secondary" },
	},

	{
		selector = ".ui-tooltip-body.ui-tooltip-variant-outline",
		priority = VARIANT,
		properties = { TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-themed-fill.ui-tooltip-variant-outline",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Background" },
	},
	{
		selector = ".ui-tooltip-arrow.ui-tooltip-themed-fill.ui-tooltip-variant-outline",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Background" },
	},

	{
		selector = ".ui-tooltip-body.ui-tooltip-variant-destructive",
		priority = VARIANT,
		properties = { TextColor3 = "$DestructiveForeground" },
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-themed-fill.ui-tooltip-variant-destructive",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Destructive" },
	},
	{
		selector = ".ui-tooltip-arrow.ui-tooltip-themed-fill.ui-tooltip-variant-destructive",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Destructive" },
	},
	{
		selector = ".ui-tooltip-stroke.ui-tooltip-themed-stroke.ui-tooltip-variant-destructive",
		priority = VARIANT,
		properties = { Color = "$Destructive" },
	},
	{
		selector = ".ui-tooltip-arrow-stroke.ui-tooltip-themed-stroke.ui-tooltip-variant-destructive",
		priority = VARIANT,
		properties = { Color = "$Destructive" },
	},

	{
		selector = ".ui-tooltip-body.ui-tooltip-variant-overlay",
		priority = VARIANT,
		properties = {
			TextColor3 = "$OverlayFillForeground",
		},
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-themed-fill.ui-tooltip-variant-overlay",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$OverlayFill" },
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-themed-alpha.ui-tooltip-variant-overlay",
		priority = VARIANT,
		properties = { BackgroundTransparency = "$OverlayFillTransparency" },
	},
	{
		selector = ".ui-tooltip-arrow.ui-tooltip-themed-fill.ui-tooltip-variant-overlay",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$OverlayFill" },
	},
	{
		selector = ".ui-tooltip-arrow.ui-tooltip-themed-alpha.ui-tooltip-variant-overlay",
		priority = VARIANT,
		properties = { BackgroundTransparency = "$OverlayFillTransparency" },
	},

	-- Border overrides
	{
		selector = ".ui-tooltip-stroke.ui-tooltip-border",
		priority = STATE,
		properties = { Thickness = "$StrokeThin", Transparency = 0 },
	},
	{
		selector = ".ui-tooltip-arrow-stroke.ui-tooltip-border",
		priority = STATE,
		properties = { Thickness = "$StrokeThin", Transparency = 0 },
	},
	{
		selector = ".ui-tooltip-stroke.ui-tooltip-no-border",
		priority = STATE,
		properties = { Thickness = 0, Transparency = 1 },
	},
	{
		selector = ".ui-tooltip-arrow-stroke.ui-tooltip-no-border",
		priority = STATE,
		properties = { Thickness = 0, Transparency = 1 },
	},

	-- Sizes
	{
		selector = ".ui-tooltip-body.ui-tooltip-size-sm",
		priority = VARIANT,
		properties = { TextSize = "$TextXs" },
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-size-sm::UIPadding",
		priority = VARIANT,
		properties = {
			PaddingLeft = "$Space2",
			PaddingRight = "$Space2",
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		},
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-size-lg",
		priority = VARIANT,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-tooltip-body.ui-tooltip-size-lg::UIPadding",
		priority = VARIANT,
		properties = {
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
			PaddingTop = "$Space2",
			PaddingBottom = "$Space2",
		},
	},
}
local function tooltipSlotFlow(ruleList: { Component.Rule }): { Component.Rule }
	local flowed = Slot.flow(ruleList)
	for _, rule in flowed do
		if string.sub(rule.selector, -12) == " >> .ui-text" then
			rule.selector = string.sub(rule.selector, 1, -13) .. " >> .ui-text-default-variant"
		end
	end
	return flowed
end

Tooltip.rules = rules
for _, rule in tooltipSlotFlow(rules) do
	table.insert(Tooltip.rules, rule)
end
for _, rule in Slot.rules do
	table.insert(Tooltip.rules, rule)
end

local extraVariants: { { key: string, rules: { Component.Rule } } } = {}

local function checkVariant(variant: string)
	if not table.find(Tooltip.variants, variant) then
		error(`[Lucy] unknown Tooltip variant "{tostring(variant)}"`, 0)
	end
end

local function checkSize(size: string)
	if not table.find(Tooltip.sizes, size) then
		error(`[Lucy] unknown Tooltip size "{tostring(size)}" (expected sm, md or lg)`, 0)
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

-- Registers a custom Tooltip variant (ADR 0022).
function Tooltip.addVariant(name: string, variantRules: { Component.Rule })
	if type(name) ~= "string" or name == "" then
		error("[Lucy] Tooltip.addVariant needs a variant name", 2)
	end
	if not table.find(Tooltip.variants, name) then
		table.insert(Tooltip.variants, name)
	end
	local key = "tooltip-variant-" .. name
	local compiled: { Component.Rule } = {}
	for _, rule in variantRules do
		local sel = rule.selector or ""
		local priority = rule.priority or VARIANT
		if sel == "" then
			local special, rest =
				splitRuleProps(rule.properties, { "BackgroundColor3", "BackgroundTransparency" })
			if next(rest) ~= nil then
				table.insert(compiled, {
					selector = `.ui-tooltip-body.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = rest,
					transitions = rule.transitions,
				})
			end
			if special.BackgroundColor3 ~= nil then
				table.insert(compiled, {
					selector = `.ui-tooltip-body.ui-tooltip-themed-fill.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = { BackgroundColor3 = special.BackgroundColor3 },
					transitions = rule.transitions,
				})
				table.insert(compiled, {
					selector = `.ui-tooltip-arrow.ui-tooltip-themed-fill.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = { BackgroundColor3 = special.BackgroundColor3 },
					transitions = rule.transitions,
				})
			end
			if special.BackgroundTransparency ~= nil then
				table.insert(compiled, {
					selector = `.ui-tooltip-body.ui-tooltip-themed-alpha.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = { BackgroundTransparency = special.BackgroundTransparency },
					transitions = rule.transitions,
				})
				table.insert(compiled, {
					selector = `.ui-tooltip-arrow.ui-tooltip-themed-alpha.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = { BackgroundTransparency = special.BackgroundTransparency },
					transitions = rule.transitions,
				})
			end
		elseif sel == "::UIStroke" then
			local colorOnly, strokeRest = splitRuleProps(rule.properties, { "Color" })
			if next(strokeRest) ~= nil then
				table.insert(compiled, {
					selector = `.ui-tooltip-stroke.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = strokeRest,
				})
				table.insert(compiled, {
					selector = `.ui-tooltip-arrow-stroke.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = strokeRest,
				})
			end
			if colorOnly.Color ~= nil then
				table.insert(compiled, {
					selector = `.ui-tooltip-stroke.ui-tooltip-themed-stroke.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = colorOnly,
				})
				table.insert(compiled, {
					selector = `.ui-tooltip-arrow-stroke.ui-tooltip-themed-stroke.ui-tooltip-variant-{name}`,
					priority = priority,
					properties = colorOnly,
				})
			end
		else
			table.insert(compiled, {
				selector = `.ui-tooltip-body.ui-tooltip-variant-{name}{sel}`,
				priority = priority,
				properties = rule.properties,
				transitions = rule.transitions,
			})
		end
	end
	for _, twin in tooltipSlotFlow(compiled) do
		table.insert(compiled, twin)
	end
	table.insert(extraVariants, { key = key, rules = compiled })
	Theme.declare(key, compiled)
end

local function parseTriggers(raw: any): { [string]: boolean }
	local list: { string }
	if raw == nil then
		list = { "hover" }
	elseif type(raw) == "string" then
		list = { raw }
	elseif type(raw) == "table" then
		list = raw
	else
		error("[Lucy] Tooltip trigger must be a string or list of strings", 3)
	end
	local out: { [string]: boolean } = {}
	for _, entry in list do
		if not table.find(Tooltip.triggers, entry) then
			error(`[Lucy] unknown Tooltip trigger "{tostring(entry)}"`, 3)
		end
		out[entry] = true
	end
	if out.hold then
		out.press = true
	end
	if out.toggle then
		out.click = true
	end
	return out
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

local spec: Component.Spec = {
	kind = "tooltip",
	defaults = {
		text = "",
		variant = "default",
		size = "md",
		side = "top",
		align = "center",
		offset = 8,
		alignOffset = 0,
		arrow = true,
		open = false,
		distance = 12,
		visible = true,
	},
	rules = Tooltip.rules,
	render = function(h)
		local p: Component.Props = h.props
		checkVariant(h:get("variant"))
		checkSize(h:get("size"))
		local triggers = parseTriggers(p.trigger)

		for _, extra in extraVariants do
			if not h.app.theme:hasRules(extra.key) then
				h.app.theme:addRules(extra.key, extra.rules, { layer = "game" })
			end
		end

		local textRef = h:ref("text")
		local variant = h:ref("variant")
		local size = h:ref("size")
		local sideRef = h:ref("side")
		local alignRef = h:ref("align")
		local offsetRef = h:ref("offset")
		local alignOffsetRef = h:ref("alignOffset")
		local arrowProp = h:ref("arrow")
		local openRef = h:ref("open")
		local distanceRef = h:ref("distance")
		local visibleRef = h:ref("visible")

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
				return "ui-tooltip-no-border"
			elseif b == true or type(b) == "string" or typeof(b) == "Color3" or p.stroke ~= nil then
				return "ui-tooltip-border"
			end
			return nil
		end

		local function variantTag(): string
			local v = variant()
			checkVariant(v)
			return "ui-tooltip-variant-" .. v
		end

		local strokeColorSource = if type(p.border) == "string" or typeof(p.border) == "Color3"
			then p.border
			else p.stroke
		local themedFillTag = if p.fill == nil then "ui-tooltip-themed-fill" else nil
		local themedAlphaTag = if p.transparency == nil then "ui-tooltip-themed-alpha" else nil
		local themedStrokeTag = if strokeColorSource == nil then "ui-tooltip-themed-stroke" else nil

		local strokeProps: { [string]: any } = {
			Name = "Stroke",
			Tags = { "ui-tooltip-stroke" :: any, variantTag, borderTag, themedStrokeTag },
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

		local arrowStrokeProps: { [any]: any } = {
			Name = "Stroke",
			Tags = { "ui-tooltip-arrow-stroke" :: any, variantTag, borderTag, themedStrokeTag },
		}
		if strokeColorSource ~= nil then
			arrowStrokeProps.Color = strokeProps.Color
		end
		if p.strokeThickness ~= nil then
			arrowStrokeProps.Thickness = p.strokeThickness
		end

		local arrowCutGrad = Element.new("UIGradient", {
			Name = "Cut",
			Transparency = ARROW_STROKE_CUT,
			Rotation = 45,
		}) :: UIGradient
		arrowStrokeProps[1] = arrowCutGrad
		local arrowStroke = Element.new("UIStroke", arrowStrokeProps) :: UIStroke
		h.arrowStroke = arrowStroke

		local arrowFillGrad = Element.new("UIGradient", {
			Name = "Cut",
			Transparency = function(): NumberSequence
				local t = Reactive.toValue(p.transparency)
				if (type(t) == "number" and t > 0) or variant() == "overlay" then
					return ARROW_STROKE_CUT
				end
				return ARROW_FILL_SOLID_CUT
			end,
			Rotation = 45,
		}) :: UIGradient

		local arrowProps: { [any]: any } = {
			Name = "Arrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(Tooltip.arrowSize, Tooltip.arrowSize),
			Rotation = 45,
			ZIndex = 3,
			Visible = function(): boolean
				return arrowProp() ~= false
			end,
			Tags = { "ui-tooltip-arrow" :: any, variantTag, borderTag, themedFillTag, themedAlphaTag },
			arrowFillGrad,
			arrowStroke,
		}
		if p.fill ~= nil then
			arrowProps.BackgroundColor3 = function(): Color3
				return resolveColorValue(h.app, themeTick, p.fill) or Color3.new(1, 1, 1)
			end
		end
		if p.transparency ~= nil then
			arrowProps.BackgroundTransparency = p.transparency
		end
		local arrowFrame = Element.new("Frame", arrowProps) :: Frame
		h.arrow = arrowFrame

		local bodyProps: { [any]: any } = {
			Name = "Body",
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			ZIndex = 2,
			Active = p.interactive == true,
			Tags = {
				"ui-tooltip-body" :: any,
				variantTag,
				borderTag,
				themedFillTag,
				themedAlphaTag,
				function(): string
					local s = size()
					checkSize(s)
					return "ui-tooltip-size-" .. s
				end,
			},
			Element.new("UISizeConstraint", {
				MaxSize = Vector2.new(p.maxWidth or Tooltip.defaultMaxWidth, math.huge),
			}),
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
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

		local body = Element.new("Frame", bodyProps) :: Frame
		h.body = body

		-- Text (Lucy.Text with all options forwarded)
		local textConfig: { [string]: any } = table.clone(p.textProps or {})
		textConfig.app = h.app
		textConfig.text = textRef
		if textConfig.autoWidth == nil then
			textConfig.autoWidth = true
		end
		if textConfig.wrap == nil then
			textConfig.wrap = true
		end
		if textConfig.layoutOrder == nil then
			textConfig.layoutOrder = 1
		end
		if textConfig.name == nil then
			textConfig.name = "Label"
		end
		if textConfig.visible == nil then
			local hasValue = textConfig.value ~= nil
			textConfig.visible = function(): boolean
				return hasValue or textRef() ~= ""
			end
		end
		local label = Text.new(textConfig)
		Element.hydrate(label.Instance, {
			Tags = {
				[Slot.TEXT_TAG] = function(): boolean
					return not label.explicitVariant()
				end,
			},
		})
		label.Instance.Parent = body
		h.label = label

		local order = 1
		if p.content ~= nil then
			if type(p.content) == "function" then
				local built = p.content(h)
				if built ~= nil then
					order = Slot.fill(body, built, { app = h.app, startOrder = order })
				end
			else
				order = Slot.fill(body, p.content, { app = h.app, startOrder = order })
			end
		end
		if p.children ~= nil then
			Slot.fill(body, p.children, { app = h.app, startOrder = order })
		end

		local arrowLayer = Element.new("Frame", {
			Name = "ArrowLayer",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			arrowFrame,
		})

		local root = Element.new("Frame", {
			Name = "Tooltip",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Visible = function(): boolean
				return openRef() and visibleRef()
			end,
			body,
			arrowLayer,
		}) :: Frame

		local hasTarget = p.target ~= nil or p.reference ~= nil
		local floating: Floating.FloatingHandle
		if hasTarget then
			floating = Floating.use(h.app, {
				reference = p.target or p.reference,
				content = root,
				open = function(): boolean
					return openRef() and visibleRef()
				end,
				placement = p.placement,
				side = sideRef,
				align = alignRef,
				offset = offsetRef,
				alignOffset = alignOffsetRef,
				studsOffset = p.studsOffset,
				avoidCollisions = p.avoidCollisions,
				flip = p.flip,
				shift = p.shift,
				padding = p.collisionPadding or p.padding,
				arrow = function(): number
					return if arrowProp() ~= false then Tooltip.arrowSize else 0
				end,
				arrowPadding = p.arrowPadding,
				maxDistance = p.maxDistance,
				alwaysOnTop = p.alwaysOnTop,
				size = p.billboardSize,
				name = "TooltipOverlay",
			})
		else
			floating = {
				world = false,
				gui = nil,
				overlay = nil,
				side = function(): string
					local s = sideRef()
					return if s == "auto" then "top" else s
				end,
				arrowOffset = function(): number
					local s = sideRef()
					local span = if s == "left" or s == "right"
						then body.AbsoluteSize.Y
						else body.AbsoluteSize.X
					return math.floor(span / 2 + 0.5)
				end,
				arrowCenter = function(): number
					return 0
				end,
				visible = function(): boolean
					return openRef() and visibleRef()
				end,
				place = function() end,
			}
		end
		h.floating = floating
		h.side = floating.side
		h.open = openRef
		h.arrowDirection = function(): string
			return ARROW_DIR[floating.side()] or "down"
		end

		local function positionArrow()
			local side = floating.side()
			local rot = ARROW_GRAD_ROT[side] or 45
			arrowFillGrad.Rotation = rot
			arrowCutGrad.Rotation = rot
			local centerOffset = if floating.arrowCenter then floating.arrowCenter() else 0
			if side == "top" then
				arrowFrame.Position = UDim2.new(0.5, centerOffset, 1, 0)
			elseif side == "bottom" then
				arrowFrame.Position = UDim2.new(0.5, centerOffset, 0, 0)
			elseif side == "left" then
				arrowFrame.Position = UDim2.new(1, 0, 0.5, centerOffset)
			else
				arrowFrame.Position = UDim2.new(0, 0, 0.5, centerOffset)
			end
		end
		Reactive.watchEffect(positionArrow)
		local bodySizeConn = body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			floating.place()
			positionArrow()
		end)
		Reactive.onCleanup(function()
			bodySizeConn:Disconnect()
		end)

		-- Triggers
		local group = Composables.useDelayGroup(h.app)
		local inputMode = h.app.state:ref("input.mode")

		if triggers.hover then
			local hover = Composables.useHover(p.target or p.reference, {
				delay = if p.delay ~= nil then p.delay else Tooltip.defaultDelay,
				closeDelay = if p.closeDelay ~= nil then p.closeDelay else Tooltip.defaultCloseDelay,
				also = if p.interactive then { body } else nil,
				group = group,
			})
			h.hover = hover
			Reactive.watch(hover.active, function(on)
				openRef(on)
			end)

			local focus = Composables.useFocus(h.app, p.target or p.reference)
			h.focus = focus
			Reactive.watch(focus.active, function(on)
				local m = Reactive.peek(inputMode)
				if m == "gamepad" or m == "keyboard" then
					openRef(on)
				end
			end)

			local long = Composables.usePress(p.target or p.reference, {
				mode = "hold",
				longPress = if p.longPress ~= nil then p.longPress else Tooltip.defaultLongPress,
			})
			Reactive.watch(long.active, function(on)
				if Reactive.peek(inputMode) == "touch" then
					openRef(on)
				end
			end)
		elseif triggers.focus then
			local focus = Composables.useFocus(h.app, p.target or p.reference)
			h.focus = focus
			Reactive.watch(focus.active, function(on)
				openRef(on)
			end)
		end

		if triggers.press then
			local press = Composables.usePress(p.target or p.reference, { mode = "hold" })
			h.press = press
			Reactive.watch(press.active, function(on)
				openRef(on)
			end)
		elseif triggers.click then
			local press = Composables.usePress(p.target or p.reference, { mode = "toggle" })
			h.press = press
			Reactive.watch(press.active, function(on)
				openRef(on)
			end)
			Reactive.watch(openRef, function(on)
				if not on and Reactive.peek(press.active) then
					press.active(false)
				end
			end)
			h.dismiss = Composables.useDismiss(h.app, openRef, {
				inside = { p.target or p.reference, body },
			})
		end

		if triggers.proximity then
			local proximity = Composables.useProximity(h.app, p.target or p.reference, {
				distance = distanceRef,
				hysteresis = p.hysteresis,
				lineOfSight = p.lineOfSight,
				origin = p.origin,
			})
			h.proximity = proximity
			Reactive.watch(proximity.active, function(on)
				openRef(on)
			end)
		end

		Reactive.watch(openRef, function(on, previous)
			if on then
				if hasTarget and not triggers.always and not triggers.manual and not triggers.proximity then
					group.claim(h.id, function()
						if not h.destroyed then
							openRef(false)
						end
					end)
				end
			else
				group.release(h.id)
			end
			if previous ~= nil and on ~= previous then
				if p.onOpenChange then
					p.onOpenChange(on, h)
				end
				h:emit(if on then "open" else "close")
			end
		end, { immediate = true })

		Reactive.onCleanup(function()
			group.release(h.id)
		end)

		function h:show()
			if not self.destroyed then
				openRef(true)
			end
		end
		function h:hide()
			if not self.destroyed then
				openRef(false)
			end
		end
		function h:toggle()
			if not self.destroyed then
				openRef(not Reactive.peek(openRef))
			end
		end

		return root
	end,
}

function Tooltip.new(props: { [string]: any }?)
	if props then
		local out: { [string]: any } = table.clone(props)
		if out.sideOffset ~= nil and out.offset == nil then
			out.offset = out.sideOffset
		end
		if out.placement ~= nil and (out.side == nil or out.align == nil) then
			local side, align = Floating.parsePlacement(out.placement, out.side, out.align)
			if out.side == nil then
				out.side = side
			end
			if out.align == nil then
				out.align = align
			end
		end
		if out.open == nil then
			local t = out.trigger
			local isAlways = t == "always" or (type(t) == "table" and table.find(t, "always") ~= nil)
			local inlineDefault = out.target == nil and out.reference == nil and t == nil
			if isAlways or inlineDefault then
				out.open = true
			end
		end
		return Component.mount(spec, out)
	end
	return Component.mount(spec, { open = true })
end

Component.define(spec)

return Tooltip
