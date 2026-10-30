--[[
	Badge

		Badge.new({ text = "New", variant = "default" }) -- default | secondary | destructive | outline

	State keys: text, variant, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)

local Badge = {}

Badge.variants = { "default", "secondary", "destructive", "outline" }

Badge.rules = {
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
		properties = { Color = "$Border", Thickness = "$StrokeThin", ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
	},
}

function Badge.new(props: { [string]: any }?)
	return Component.mount({
		kind = "badge",
		props = props,
		defaults = { text = "Badge", variant = "default", visible = true },
		rules = Badge.rules,
		render = function()
			return Component.create("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				Tags = { "ui-badge" },
			})
		end,
		update = function(h, state)
			if not table.find(Badge.variants, state.variant) then
				error(`[Lucy] unknown Badge variant "{state.variant}"`, 3)
			end
			h.Instance.Text = state.text
			h.Instance.Visible = state.visible
			Component.setVariant(h.Instance, "ui-badge", "variant", state.variant)
		end,
	})
end

return Badge
