--!strict
--[[
	Button

		Button.new({
			text = "Play",
			variant = "default",   -- default | destructive | outline | secondary | ghost | link
			size = "md",           -- sm | md | lg | icon
			disabled = false,
			visible = true,
			onClick = function(button) end,
			id = "play",           -- state lives at ui.play
			Parent = frame,
		})

	State keys: text, variant, size, disabled, visible.
	Events: button.Activated (Signal). button:click() runs the click path in code/tests
	(Component.clickable).

	Visuals live in Button.rules (Universal Styling); code only sets behaviour and
	layout so a rule is never overridden by an instance property.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

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
		local variant, size, disabled = h:ref("variant"), h:ref("size"), h:ref("disabled")
		local function enabled(): boolean
			return not disabled()
		end
		return Element.new("TextButton", {
			AutoButtonColor = false,
			Text = h:ref("text"),
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
		})
	end,
}

function Button.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	Component.clickable(handle)
	return handle
end

return Button
