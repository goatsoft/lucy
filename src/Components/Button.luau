--!strict
--[[
	Button

		Button.new({
			text = "Play",
			variant = "default",   -- default | destructive | outline | secondary | ghost | link
			size = "md",           -- sm | md | lg | icon
			disabled = false,
			visible = true,
			hint = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.DPadUp }, -- optional key cap
			onClick = function(button) end,
			id = "play",           -- state lives at ui.play
			Parent = frame,
		})

	State keys: text, variant, size, disabled, visible.
	With `hint` (Kbd props), the text moves into button.label and button.hint (a
	Kbd) follows it: the key for the player's input, hidden on touch. The label's
	rules are made from the button's own text rules, so it looks the same.
	Events: button.Activated (Signal). button:click() runs the click path in code/tests
	(Component.clickable).

	Visuals live in Button.rules (Universal Styling); code only sets behaviour and
	layout so a rule is never overridden by an instance property.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Kbd = require(script.Parent.Kbd)

local Button = {}

Button.variants = { "default", "destructive", "outline", "secondary", "ghost", "link" }
Button.sizes = { "sm", "md", "lg", "icon" }

local ACTIVATED = Element.on("Activated") -- built once, not per button

local BASE, VARIANT, STATE, DISABLED = 0, 10, 20, 30

local rules: { Component.Rule } = {
	{
		selector = ".ui-button",
		priority = BASE,
		properties = {
			BackgroundColor3 = "$Primary",
			TextColor3 = "$PrimaryForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
			BorderSizePixel = 0,
			Size = "$ControlMd",
		},
		transitions = { BackgroundColor3 = TweenInfo.new(0.12) },
	},
	{ selector = ".ui-button::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-button::UIPadding",
		priority = BASE,
		properties = { PaddingLeft = "$Space4", PaddingRight = "$Space4" },
	},

	-- Variants
	{
		selector = ".ui-button-variant-default:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$PrimaryHover" },
	},
	{
		selector = ".ui-button-variant-destructive",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Destructive", TextColor3 = "$DestructiveForeground" },
	},
	{
		selector = ".ui-button-variant-destructive:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$DestructiveHover" },
	},
	{
		selector = ".ui-button-variant-outline",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Background", TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-button-variant-outline::UIStroke",
		priority = VARIANT,
		properties = {
			Color = "$Input",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	{
		selector = ".ui-button-variant-outline:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$Accent", TextColor3 = "$AccentForeground" },
	},
	{
		selector = ".ui-button-variant-secondary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Secondary", TextColor3 = "$SecondaryForeground" },
	},
	{
		selector = ".ui-button-variant-secondary:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$SecondaryHover" },
	},
	{
		selector = ".ui-button-variant-ghost",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-button-variant-ghost:Hover",
		priority = STATE,
		properties = { BackgroundTransparency = 0, TextColor3 = "$AccentForeground" },
	},
	{
		selector = ".ui-button-variant-link",
		priority = VARIANT,
		properties = { BackgroundTransparency = 1, TextColor3 = "$Primary" },
	},
	{
		selector = ".ui-button-variant-link:Hover",
		priority = STATE,
		properties = { TextColor3 = "$MutedForeground" },
	},

	-- Sizes
	{
		selector = ".ui-button-size-sm",
		priority = VARIANT,
		properties = { Size = "$ControlSm", TextSize = "$TextXs" },
	},
	{
		selector = ".ui-button-size-sm::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space3", PaddingRight = "$Space3" },
	},
	{
		selector = ".ui-button-size-lg",
		priority = VARIANT,
		properties = { Size = "$ControlLg", TextSize = "$TextBase" },
	},
	{
		selector = ".ui-button-size-lg::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space6", PaddingRight = "$Space6" },
	},
	{
		selector = ".ui-button-size-icon",
		priority = VARIANT,
		properties = { Size = "$ControlIcon", TextSize = "$TextBase" },
	},
	{
		selector = ".ui-button-size-icon::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space0", PaddingRight = "$Space0" },
	},

	-- Disabled (the component also sets Interactable = false)
	{ selector = ".ui-button.ui-disabled", priority = DISABLED, properties = { TextTransparency = 0.5 } },
}
Button.rules = rules
-- Solid variants fade their background when disabled; transparent ones stay transparent.
for _, variant in { "default", "destructive", "outline", "secondary" } do
	table.insert(Button.rules, {
		selector = `.ui-button-variant-{variant}.ui-disabled`,
		priority = DISABLED,
		properties = { BackgroundTransparency = 0.5 },
	})
end

-- A hinted button carries its text in a child label. Every rule that sets text
-- properties on the button gets a twin for that label, so variants, sizes,
-- hover and disabled read the same.
local TEXT_PROPERTIES = { "TextColor3", "TextTransparency", "FontFace", "TextSize" }
local labelRules: { Component.Rule } = {
	{ selector = ".ui-button-label", priority = BASE, properties = { BackgroundTransparency = 1 } },
}
for _, rule in Button.rules do
	if not string.find(rule.selector, "::", 1, true) then
		local properties: { [string]: any } = {}
		local any = false
		for _, name in TEXT_PROPERTIES do
			local value = (rule.properties :: any)[name]
			if value ~= nil then
				properties[name] = value
				any = true
			end
		end
		if any then
			table.insert(labelRules, {
				selector = rule.selector .. " > .ui-button-label",
				priority = rule.priority,
				properties = properties,
			})
		end
		-- A controller picture in the hint takes the button's text colour; one above
		-- the button's own priority so it beats the key cap's default.
		local colour = (rule.properties :: any).TextColor3
		if colour ~= nil then
			table.insert(labelRules, {
				selector = rule.selector .. " >> .ui-kbd-image",
				priority = (rule.priority or 0) + 1,
				properties = { ImageColor3 = colour },
			})
		end
	end
end
for _, rule in labelRules do
	table.insert(Button.rules, rule)
end

local function check(list: { string }, value: string, what: string)
	if not table.find(list, value) then
		error(`[Lucy] unknown Button {what} "{value}" (expected {table.concat(list, ", ")})`, 0)
	end
end

-- One tag list per variant and size pair, built on first use and shared by every
-- Button, so changing a variant or size builds nothing.
local tagLists: { [string]: { [string]: { string } } } = {}
local function variantTags(variant: string, size: string): { string }
	local bySize = tagLists[variant]
	if not bySize then
		bySize = {}
		tagLists[variant] = bySize
	end
	local list = bySize[size]
	if not list then
		list = { "ui-button-variant-" .. variant, "ui-button-size-" .. size }
		bySize[size] = list
	end
	return list
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "button",
	defaults = { text = "Button", variant = "default", size = "md", disabled = false, visible = true },
	rules = Button.rules,
	render = function(h)
		-- An unknown variant or size fails the mount; later writes report like any effect.
		check(Button.variants, h:get("variant"), "variant")
		check(Button.sizes, h:get("size"), "size")
		local p: Component.Props = h.props
		local variant, size, disabled = h:ref("variant"), h:ref("size"), h:ref("disabled")
		local function enabled(): boolean
			return not disabled()
		end
		local hint: { [string]: any }? = p.hint
		local label: TextLabel? = nil
		local layout: UIListLayout? = nil
		if hint then
			label = Element.new("TextLabel", {
				Name = "Label",
				LayoutOrder = 1,
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = h:ref("text"),
				Tags = { "ui-button-label" },
			})
			layout = Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			})
			h.label = label
		end
		local root = Element.new("TextButton", {
			AutoButtonColor = false,
			Text = if hint then "" else h:ref("text"),
			Visible = h:ref("visible"),
			Interactable = enabled,
			Selectable = enabled,
			AutomaticSize = function()
				return if size() == "icon" then Enum.AutomaticSize.None else Enum.AutomaticSize.X
			end,
			Tags = {
				"ui-button" :: any,
				-- Variant and size in one binding: they rarely change, so one effect, not two.
				function()
					local v, s = variant(), size()
					check(Button.variants, v, "variant")
					check(Button.sizes, s, "size")
					return variantTags(v, s)
				end,
				["ui-disabled"] = disabled,
			},
			[ACTIVATED] = function()
				h:click()
			end,
			layout :: any,
			label :: any,
		})
		if hint then
			-- Made in render, so it is the button's and goes with it.
			local kbdProps = table.clone(hint)
			kbdProps.app = h.app
			kbdProps.layoutOrder = 2
			kbdProps.Parent = root
			h.hint = Kbd.new(kbdProps)
		end
		return root
	end,
}

function Button.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	Component.clickable(handle)
	return handle
end

return Button
