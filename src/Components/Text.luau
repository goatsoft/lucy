--[[
	Text: headings, body copy and labels.

		Text.new({ text = "Turf Heist", variant = "h1", align = "center" })

	variant: h1 | h2 | h3 | h4 | p | lead | large | small | muted | label
	align:   left | center | right
	autoWidth = true sizes to the text instead of filling the parent's width.

	State keys: text, variant, align, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)

local Text = {}

Text.variants = {
	h1 = { TextSize = "$Text4xl", FontFace = "$FontDisplay" },
	h2 = { TextSize = "$Text3xl", FontFace = "$FontDisplay" },
	h3 = { TextSize = "$Text2xl", FontFace = "$FontDisplay" },
	h4 = { TextSize = "$TextXl", FontFace = "$FontDisplay" },
	p = { TextSize = "$TextBase", FontFace = "$FontSans" },
	lead = { TextSize = "$TextXl", FontFace = "$FontSans", TextColor3 = "$MutedForeground" },
	large = { TextSize = "$TextLg", FontFace = "$FontSansSemibold" },
	small = { TextSize = "$TextSm", FontFace = "$FontSansMedium" },
	muted = { TextSize = "$TextSm", FontFace = "$FontSans", TextColor3 = "$MutedForeground" },
	label = { TextSize = "$TextSm", FontFace = "$FontSansMedium" },
}

local ALIGN = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}

Text.rules = {
	{
		selector = ".ui-text",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSans",
			TextSize = "$TextBase",
		},
	},
}
for name, properties in Text.variants do
	table.insert(Text.rules, { selector = `.ui-text-variant-{name}`, priority = 10, properties = properties })
end

function Text.new(props: { [string]: any }?)
	local p = props or {}
	return Component.mount({
		kind = "text",
		props = p,
		defaults = { text = "", variant = "p", align = "left", visible = true },
		rules = Text.rules,
		render = function()
			return Component.create("TextLabel", {
				Size = if p.autoWidth then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0),
				AutomaticSize = if p.autoWidth then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
				TextWrapped = not p.autoWidth,
				RichText = p.richText == true,
				Tags = { "ui-text" },
			})
		end,
		update = function(h, state)
			if Text.variants[state.variant] == nil then
				error(`[Lucy] unknown Text variant "{state.variant}"`, 3)
			end
			h.Instance.Text = state.text
			h.Instance.Visible = state.visible
			h.Instance.TextXAlignment = ALIGN[state.align] or Enum.TextXAlignment.Left
			Component.setVariant(h.Instance, "ui-text", "variant", state.variant)
		end,
	})
end

return Text
