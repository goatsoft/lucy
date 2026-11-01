--!strict
--[[
	Badge

		Badge.new({
			text = "New",
			variant = "default",   -- default | secondary | destructive | outline
			shape = "rounded",     -- rounded | square (only slightly rounded, $RadiusXs, and a
			                       -- tighter fit: a tag or a label)
		})

	State keys: text, variant, shape, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Badge = {}

Badge.variants = { "default", "secondary", "destructive", "outline" }
Badge.shapes = { "rounded", "square" }

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
	-- square: the smallest radius and a tighter fit, for tags and labels that should not read as pills
	{
		selector = ".ui-badge-shape-square::UICorner",
		priority = 5,
		properties = { CornerRadius = "$RadiusXs" },
	},
	{
		selector = ".ui-badge-shape-square::UIPadding",
		priority = 5,
		properties = { PaddingLeft = "$Space1", PaddingRight = "$Space1" },
	},
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

local function checkShape(shape: string)
	if not table.find(Badge.shapes, shape) then
		error(`[Lucy] unknown Badge shape "{shape}" (expected {table.concat(Badge.shapes, ", ")})`, 0)
	end
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "badge",
	defaults = { text = "Badge", variant = "default", shape = "rounded", visible = true },
	rules = Badge.rules,
	render = function(h)
		check(h:get("variant")) -- an unknown variant or shape fails the mount
		checkShape(h:get("shape"))
		local variant = h:ref("variant")
		local shape = h:ref("shape")
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
				["ui-badge-shape-square"] = function(): boolean
					local name = shape()
					checkShape(name)
					return name == "square"
				end,
			},
		})
	end,
}

function Badge.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Badge
