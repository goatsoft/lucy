--!strict
--[[
	Badge

		Badge.new({ text = "New", variant = "default" }) -- default | secondary | destructive | outline

	State keys: text, variant, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Badge = {}

Badge.variants = { "default", "secondary", "destructive", "outline" }

local rules: { Component.Rule } = {
	{
		selector = ".ui-badge",
		priority = 0,
		properties = {
			BackgroundColor3 = "$Primary",
			TextColor3 = "$PrimaryForeground",
			FontFace = "$FontSansSemibold",
			TextSize = "$TextXs",
			BorderSizePixel = 0,
		},
	},
	{ selector = ".ui-badge::UICorner", priority = 0, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-badge::UIPadding",
		priority = 0,
		properties = {
			PaddingLeft = "$Space2",
			PaddingRight = "$Space2",
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		},
	},
	{
		selector = ".ui-badge-variant-secondary",
		priority = 10,
		properties = { BackgroundColor3 = "$Secondary", TextColor3 = "$SecondaryForeground" },
	},
	{
		selector = ".ui-badge-variant-destructive",
		priority = 10,
		properties = { BackgroundColor3 = "$Destructive", TextColor3 = "$DestructiveForeground" },
	},
	{
		selector = ".ui-badge-variant-outline",
		priority = 10,
		properties = { BackgroundTransparency = 1, TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-badge-variant-outline::UIStroke",
		priority = 10,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
}
Badge.rules = rules

local function check(variant: string)
	if not table.find(Badge.variants, variant) then
		error(`[Lucy] unknown Badge variant "{variant}"`, 0)
	end
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "badge",
	defaults = { text = "Badge", variant = "default", visible = true },
	rules = Badge.rules,
	render = function(h)
		check(h:get("variant")) -- an unknown variant fails the mount
		local variant = h:ref("variant")
		return Element.new("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = h:ref("text"),
			Visible = h:ref("visible"),
			Tags = {
				"ui-badge" :: any,
				function()
					local name = variant()
					check(name)
					return "ui-badge-variant-" .. name
				end,
			},
		})
	end,
}

function Badge.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Badge
