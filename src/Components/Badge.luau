--!strict
--[[
	Badge

		Badge.new({
			text = "New",
			variant = "default",   -- default | secondary | destructive | outline | overlay (a
			                       -- see-through fill over a picture: a count on an item)
			shape = "rounded",     -- rounded | square (only slightly rounded, $RadiusXs, and a
			                       -- tighter fit: a tag or a label)
			size = "sm",           -- sm | md | lg | xl: its words as a Button's of that size, its
			                       -- icon and padding growing with them
			icon = "lucide:bot",   -- optional: before the text, or alone
			children = { ... },    -- optional: anything, in a row (Slot: strings, handles,
			                       -- instances, builders), after the icon and the text
		})

	A badge is a box with a slot (ADR 0042): its icon, text and children sit in a row and take
	its colours (Slot.flow), so a tinted badge tints all of it. With only text, the text is the
	badge's own. State keys: text, icon, variant, shape, size, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Slot = require(script.Parent.Slot)
local Text = require(script.Parent.Text)

local Badge = {}

Badge.variants = { "default", "secondary", "destructive", "outline", "overlay" }
Badge.shapes = { "rounded", "square" }
Badge.sizes = { "sm", "md", "lg", "xl" }
-- Each size's icon in pixels (sm keeps the badge's first size)
Badge.iconSizes = { sm = 14, md = 16, lg = 20, xl = 24 }

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
	-- Over a picture (a count on an item's render): a see-through fill, dark with white words in
	-- the dark theme and light with dark words in the light one
	{
		selector = ".ui-badge-variant-overlay",
		priority = 10,
		properties = {
			BackgroundColor3 = "$OverlayFill",
			BackgroundTransparency = "$OverlayFillTransparency",
			TextColor3 = "$OverlayFillForeground",
		},
	},
	-- Sizes: the words as a Button's of the same size (sm is the base rules above), and a little
	-- more room round them as they grow
	{ selector = ".ui-badge-size-md", priority = 5, properties = { TextSize = "$TextSm" } },
	{
		selector = ".ui-badge-size-md::UIPadding",
		priority = 6,
		properties = { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) },
	},
	{ selector = ".ui-badge-size-lg", priority = 5, properties = { TextSize = "$TextBase" } },
	{
		selector = ".ui-badge-size-lg::UIPadding",
		priority = 6,
		properties = {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = "$Space3",
			PaddingRight = "$Space3",
		},
	},
	{ selector = ".ui-badge-size-xl", priority = 5, properties = { TextSize = "$TextLg" } },
	{
		selector = ".ui-badge-size-xl::UIPadding",
		priority = 6,
		properties = {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = "$Space3",
			PaddingRight = "$Space3",
		},
	},
}
Badge.rules = rules
-- What sits in the slot takes the badge's colours (ADR 0042)
for _, rule in Slot.flow(rules) do
	table.insert(Badge.rules, rule)
end
for _, rule in Slot.rules do
	table.insert(Badge.rules, rule)
end
-- The slot's words: the badge's size and weight. ICON_SIZE is sm's icon (kept for games that
-- read it)
Badge.ICON_SIZE = Badge.iconSizes.sm

local function check(variant: string)
	if not table.find(Badge.variants, variant) then
		error(`[Lucy] unknown Badge variant "{variant}"`, 0)
	end
end

local function checkSize(size: string)
	if not table.find(Badge.sizes, size) then
		error(`[Lucy] unknown Badge size "{size}" (expected {table.concat(Badge.sizes, ", ")})`, 0)
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
	defaults = {
		text = "Badge",
		icon = "",
		variant = "default",
		shape = "rounded",
		size = "sm",
		visible = true,
	},
	rules = Badge.rules,
	render = function(h)
		check(h:get("variant")) -- an unknown variant or shape fails the mount
		checkShape(h:get("shape"))
		checkSize(h:get("size"))
		local p: Component.Props = h.props
		local variant = h:ref("variant")
		local shape = h:ref("shape")
		local size = h:ref("size")
		-- A slot when there is more than words: the icon, the text and the children in a row
		local slotted = p.icon ~= nil or p.children ~= nil
		local root = Element.new("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = if slotted then "" else h:ref("text"),
			Visible = h:ref("visible"),
			Tags = {
				"ui-badge" :: any,
				function()
					local name = variant()
					check(name)
					return "ui-badge-variant-" .. name
				end,
				function()
					local name = size()
					checkSize(name)
					return "ui-badge-size-" .. name
				end,
				["ui-badge-shape-square"] = function(): boolean
					local name = shape()
					checkShape(name)
					return name == "square"
				end,
			},
		}) :: TextLabel
		if slotted then
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				Parent = root,
			})
			local icon, text = h:ref("icon"), h:ref("text")
			local mark = Icon.new({
				app = h.app,
				icon = icon,
				size = function(): number
					return Badge.iconSizes[size()] or Badge.ICON_SIZE
				end,
				name = "Icon",
				layoutOrder = 1,
				visible = function(): boolean
					return icon() ~= ""
				end,
			})
			mark.Instance.Parent = root
			h.icon = mark
			local words = Text.new({
				app = h.app,
				text = text,
				autoWidth = true,
				name = "Label",
				layoutOrder = 2,
				visible = function(): boolean
					return text() ~= ""
				end,
			})
			words.Instance:AddTag(Slot.TEXT_TAG)
			words.Instance.Parent = root
			h.label = words
			Slot.fill(root, p.children, { app = h.app, startOrder = 2 })
		end
		return root
	end,
}

function Badge.new(props: { [string]: any }?)
	-- An icon or children with no text: no default text beside them
	if props and (props.icon ~= nil or props.children ~= nil) and props.text == nil then
		props = table.clone(props)
		props.text = ""
	end
	return Component.mount(spec, props)
end

return Badge
