--!strict
--[[
	Toggle: a button that stays pressed until clicked again (bold, mute, a filter).

		Toggle.new({
			text = "Bold",
			pressed = false,
			variant = "default",   -- default | outline
			size = "md",           -- sm | md | lg
			disabled = false,
			visible = true,
			children = { icon },   -- optional: shown in place of text
			onPressedChange = function(pressed, toggle) end,
			Parent = toolbar,
		})
		toggle:toggle()

	State keys: text, pressed, variant, size, disabled, visible.
	Events: "toggle" with the new value, for Lucy.useUiSound.

	ToggleGroup items share these rules and tags (Toggle.tags, Toggle.check).
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Toggle = {}

Toggle.variants = { "default", "outline" }
Toggle.sizes = { "sm", "md", "lg" }

local ACTIVATED = Element.on("Activated")

local BASE, VARIANT, STATE, SELECTED, DISABLED = 0, 10, 20, 25, 30

Toggle.rules = {
	{
		selector = ".ui-toggle",
		priority = BASE,
		properties = {
			BackgroundColor3 = "$Accent",
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
			BorderSizePixel = 0,
			Size = "$ControlMd",
		},
		transitions = { BackgroundTransparency = TweenInfo.new(0.12), BackgroundColor3 = TweenInfo.new(0.12) },
	},
	{ selector = ".ui-toggle::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-toggle::UIPadding",
		priority = BASE,
		properties = { PaddingLeft = "$Space3", PaddingRight = "$Space3" },
	},
	{
		selector = ".ui-toggle:Hover",
		priority = STATE,
		properties = {
			BackgroundColor3 = "$Muted",
			BackgroundTransparency = 0,
			TextColor3 = "$MutedForeground",
		},
	},
	{
		selector = ".ui-toggle-variant-outline::UIStroke",
		priority = VARIANT,
		properties = {
			Color = "$Input",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	{
		selector = ".ui-toggle-variant-outline:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$Accent", TextColor3 = "$AccentForeground" },
	},
	{
		selector = ".ui-toggle.ui-selected",
		priority = SELECTED,
		properties = {
			BackgroundColor3 = "$Accent",
			BackgroundTransparency = 0,
			TextColor3 = "$AccentForeground",
		},
	},
	{
		selector = ".ui-toggle-size-sm",
		priority = VARIANT,
		properties = { Size = "$ControlSm", TextSize = "$TextXs" },
	},
	{
		selector = ".ui-toggle-size-sm::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space2", PaddingRight = "$Space2" },
	},
	{
		selector = ".ui-toggle-size-lg",
		priority = VARIANT,
		properties = { Size = "$ControlLg", TextSize = "$TextBase" },
	},
	{
		selector = ".ui-toggle-size-lg::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space4", PaddingRight = "$Space4" },
	},
	{ selector = ".ui-toggle.ui-disabled", priority = DISABLED, properties = { TextTransparency = 0.5 } },
	{
		selector = ".ui-toggle.ui-selected.ui-disabled",
		priority = DISABLED,
		properties = { BackgroundTransparency = 0.5 },
	},
} :: { Component.Rule }

function Toggle.check(variant: string, size: string)
	if not table.find(Toggle.variants, variant) then
		error(`[Lucy] unknown Toggle variant "{variant}" (expected {table.concat(Toggle.variants, ", ")})`, 0)
	end
	if not table.find(Toggle.sizes, size) then
		error(`[Lucy] unknown Toggle size "{size}" (expected {table.concat(Toggle.sizes, ", ")})`, 0)
	end
end

-- One tag list per variant and size pair, shared by every toggle and group item.
local tagLists: { [string]: { string } } = {}
function Toggle.tags(variant: string, size: string): { string }
	local key = variant .. "/" .. size
	local list = tagLists[key]
	if not list then
		list = { "ui-toggle-variant-" .. variant, "ui-toggle-size-" .. size }
		tagLists[key] = list
	end
	return list
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "toggle",
	defaults = {
		text = "",
		pressed = false,
		variant = "default",
		size = "md",
		disabled = false,
		visible = true,
	},
	rules = Toggle.rules,
	render = function(h)
		local p: Component.Props = h.props
		Toggle.check(h:get("variant"), h:get("size"))
		local variant, size = h:ref("variant"), h:ref("size")
		local pressed, disabled = h:ref("pressed"), h:ref("disabled")
		local function enabled(): boolean
			return not disabled()
		end

		if p.onPressedChange then
			Reactive.watch(pressed, function(value)
				p.onPressedChange(value, h)
			end)
		end

		local root = Element.new("TextButton", {
			AutoButtonColor = false,
			Text = if p.children then "" else h:ref("text"),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = h:ref("visible"),
			Interactable = enabled,
			Selectable = enabled,
			Tags = {
				"ui-toggle" :: any,
				function()
					local v, s = variant(), size()
					Toggle.check(v, s)
					return Toggle.tags(v, s)
				end,
				["ui-selected"] = pressed,
				["ui-disabled"] = disabled,
			},
			[ACTIVATED] = function()
				h:toggle()
			end,
		})
		Component.adopt(root, p.children)
		return root
	end,
}

function Toggle.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	function handle.toggle(h)
		if h:get("disabled") then
			return
		end
		local pressed = not h:get("pressed")
		h:set("pressed", pressed)
		h:emit("toggle", pressed)
	end
	return handle
end

return Toggle
