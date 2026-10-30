--!strict
--[[
	Panel: a card with header, content and footer.

		local panel = Panel.new({
			title = "Loadout",
			description = "Pick a weapon",
			children = { ... },          -- into panel.content
			footer = { Button.new({ text = "Save" }) },
			size = UDim2.fromOffset(360, 0),      -- default: fill width, auto height
			maxWidth = 480,              -- UISizeConstraint
			aspectRatio = 16 / 9,        -- UIAspectRatioConstraint (fixed-shape panels)
		})
		panel.header, panel.content, panel.footer   -- frames to add to later

	State keys: title, description, visible.
]]

local Adaptive = require(script.Parent.Parent.Core.Adaptive)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Panel = {}

local rules: { Component.Rule } = {
	{
		selector = ".ui-panel",
		priority = 0,
		properties = { BackgroundColor3 = "$Card", BorderSizePixel = 0 },
	},
	{ selector = ".ui-panel::UICorner", priority = 0, properties = { CornerRadius = "$RadiusXl" } },
	{
		selector = ".ui-panel::UIStroke",
		priority = 0,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	{
		selector = ".ui-panel::UIPadding",
		priority = 0,
		properties = {
			PaddingTop = "$Space6",
			PaddingBottom = "$Space6",
			PaddingLeft = "$Space6",
			PaddingRight = "$Space6",
		},
	},
	{
		selector = ".ui-panel-title",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$CardForeground",
			FontFace = "$FontDisplay",
			TextSize = "$TextLg",
		},
	},
	{
		selector = ".ui-panel-description",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
}
Panel.rules = rules

local function label(tag: string, order: number, text: () -> string): TextLabel
	return Element.new("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Text = text,
		Visible = function()
			return text() ~= ""
		end,
		Tags = { tag },
	})
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "panel",
	defaults = { title = "", description = "", visible = true },
	rules = Panel.rules,
	render = function(h)
		local p: Component.Props = h.props
		local title, description = h:ref("title"), h:ref("description")
		h.title = label("ui-panel-title", 1, title)
		h.description = label("ui-panel-description", 2, description)
		local header = Element.new("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Visible = function()
				return title() ~= "" or description() ~= ""
			end,
			Component.list({ Padding = UDim.new(0, 6) }) :: any,
			h.title,
			h.description,
		})

		-- Content and footer are static frames the app fills, so plain instances.
		local content = Component.box({ Name = "Content", LayoutOrder = 2 })
		Component.list({ Padding = Component.space(h.app, "Space4", 16), Parent = content })

		local footer = Component.box({ Name = "Footer", LayoutOrder = 3 })
		Component.list({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = Component.space(h.app, "Space2", 8),
			Parent = footer,
		})

		local frame = Element.new("Frame", {
			Size = p.size or UDim2.fromScale(1, 0),
			AutomaticSize = if p.size and p.size.Y.Offset ~= 0
				then Enum.AutomaticSize.None
				else Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			Tags = { "ui-panel" },
			Component.list({ Padding = Component.space(h.app, "Space6", 24) }) :: any,
			header,
			content,
			footer,
		})

		h.header, h.content, h.footer = header, content, footer
		Component.adopt(content, p.children)
		Component.adopt(footer, p.footer)
		footer.Visible = p.footer ~= nil

		if p.maxWidth or p.minWidth then
			Adaptive.clamp(
				frame,
				Vector2.new(p.minWidth or 0, 0),
				Vector2.new(p.maxWidth or math.huge, math.huge)
			)
		end
		if p.aspectRatio then
			Adaptive.aspect(frame, p.aspectRatio)
		end
		return frame
	end,
}

function Panel.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Panel
