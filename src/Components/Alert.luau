--!strict
--[[
	Alert: a box that calls attention to a message, such as a server notice.

		Alert.new({
			title = "Server restarting",
			description = "Your progress is saved.", -- hidden when empty
			variant = "default",      -- default | destructive | success | warning | info
			icon = icon,              -- an instance or handle before the text
			children = { button },    -- more content under the description
			Parent = frame,
		})

	State keys: title, description, variant, visible.
	Parts: alert.icon, alert.content, alert.title, alert.description.
	It fills the width of its parent and grows to fit its text. For a message that
	comes and goes on its own, use app.toast instead.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Alert = {}

Alert.variants = { "default", "destructive", "success", "warning", "info" }

-- Variant colour for the title and the ring; the body text stays muted.
local TONES = {
	destructive = "$Destructive",
	success = "$Success",
	warning = "$Warning",
	info = "$Info",
}

local BASE, VARIANT = 0, 10

local rules: { Component.Rule } = {
	{
		selector = ".ui-alert",
		priority = BASE,
		properties = { BackgroundColor3 = "$Card", BorderSizePixel = 0 },
	},
	{ selector = ".ui-alert::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-alert::UIStroke",
		priority = BASE,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	{
		selector = ".ui-alert::UIPadding",
		priority = BASE,
		properties = {
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
			PaddingTop = "$Space3",
			PaddingBottom = "$Space3",
		},
	},
	{
		selector = ".ui-alert-title",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$CardForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-alert-description",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
}
for variant, colour in TONES do
	table.insert(rules, {
		selector = `.ui-alert-variant-{variant}::UIStroke`,
		priority = VARIANT,
		properties = { Color = colour },
	})
	table.insert(rules, {
		selector = `.ui-alert-title-{variant}`,
		priority = VARIANT,
		properties = { TextColor3 = colour },
	})
end
Alert.rules = rules

local function check(variant: string)
	if not table.find(Alert.variants, variant) then
		error(`[Lucy] unknown Alert variant "{variant}" (expected {table.concat(Alert.variants, ", ")})`, 0)
	end
end

local function hasText(ref: () -> any): () -> boolean
	return function()
		return ref() ~= ""
	end
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "alert",
	defaults = { title = "", description = "", variant = "default", visible = true },
	rules = Alert.rules,
	render = function(h)
		local p: Component.Props = h.props
		check(h:get("variant"))
		local variant, titleText, descriptionText = h:ref("variant"), h:ref("title"), h:ref("description")

		local title = Element.new("TextLabel", {
			Name = "Title",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = titleText,
			Visible = hasText(titleText),
			Tags = {
				"ui-alert-title" :: any,
				function()
					return "ui-alert-title-" .. variant()
				end,
			},
		})
		local description = Element.new("TextLabel", {
			Name = "Description",
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = descriptionText,
			Visible = hasText(descriptionText),
			Tags = { "ui-alert-description" },
		})
		local content = Element.new("Frame", {
			Name = "Content",
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			title,
			description,
		})
		Component.adopt(content, p.children, 2)

		local icon = Element.new("Frame", {
			Name = "Icon",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = p.icon ~= nil,
		})
		Component.adopt(icon, p.icon)
		h.icon, h.content, h.title, h.description = icon, content, title, description

		return Element.new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			Tags = {
				"ui-alert" :: any,
				function()
					local name = variant()
					check(name)
					return "ui-alert-variant-" .. name
				end,
			},
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0, 12),
			}),
			icon,
			content,
		})
	end,
}

function Alert.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Alert
