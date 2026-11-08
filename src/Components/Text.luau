--!strict
--[[
	Text: headings, body copy and labels.

		Text.new({ text = "Turf Heist", variant = "h1", align = "center" })

	variant: h1 | h2 | h3 | h4 | p | lead | large | small | muted | label
	align:   left | center | right
	autoWidth = true sizes to the text instead of filling the parent's width.

	Shortcuts for two text animations (each is a composable any label can use on its own):
	reveal = 30 types the text out, 30 characters a second (true: Text.REVEAL_RATE), again from
	the start whenever it changes (Lucy.useReveal). text:skipReveal() shows the rest at once;
	text.Revealed (a Signal) fires when it is all out.
	value = 4200 shows a number instead of text, through `format` (default Lucy.Format.number,
	"4,200"; give your own, "+250 XP"). count = 0.8 counts up to it over that many seconds
	(true: Text.COUNT_SECONDS), from `from` (default 0) and on from where it is when the value
	changes (Lucy.useCount). text:skipCount() lands it at once; text.Counted fires when it lands.

	State keys: text, variant, align, visible, value, revealing and counting (read only: typing
	out, counting up now).
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Format = require(script.Parent.Parent.Utils.Format)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Text = {}

-- Characters a second for reveal = true
Text.REVEAL_RATE = 40
-- Seconds for count = true
Text.COUNT_SECONDS = 0.8

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

local rules: { Component.Rule } = {
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
Text.rules = rules
for name, properties in Text.variants do
	table.insert(
		Text.rules,
		{ selector = `.ui-text-variant-{name}`, priority = 10, properties = properties :: { [string]: any } }
	)
end

local function check(variant: string)
	if Text.variants[variant] == nil then
		error(`[Lucy] unknown Text variant "{variant}"`, 0)
	end
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "text",
	defaults = {
		text = "",
		variant = "p",
		align = "left",
		visible = true,
		value = 0,
		revealing = false,
		counting = false,
	},
	rules = Text.rules,
	render = function(h)
		local p: Component.Props = h.props
		check(h:get("variant")) -- an unknown variant fails the mount
		local variant, align = h:ref("variant"), h:ref("align")
		local rate = if p.reveal == true
			then Text.REVEAL_RATE
			elseif type(p.reveal) == "number" then p.reveal
			else nil
		local visible: any = -1
		if rate then
			local typed = Composables.useReveal(h:ref("text"), { rate = rate, rich = p.richText == true })
			visible = typed.visible
			h.Revealed = typed.done
			function h.skipReveal(_self)
				typed.skip()
			end
			Reactive.watch(typed.revealing, function(on)
				h:set("revealing", on)
			end, { immediate = true })
		end
		-- A number (value) rather than text, counted up when count is set
		local display: any = h:ref("text")
		if p.value ~= nil then
			local format = if type(p.format) == "function" then p.format else Format.number
			local seconds = if p.count == true
				then Text.COUNT_SECONDS
				elseif type(p.count) == "number" then p.count
				else 0
			local number: any = h:ref("value")
			if seconds > 0 then
				local count = Composables.useCount(number, { seconds = seconds, from = tonumber(p.from) })
				number = count.value
				h.Counted = count.done
				function h.skipCount(_self)
					count.skip()
				end
				Reactive.watch(count.counting, function(on)
					h:set("counting", on)
				end, { immediate = true })
			end
			display = function()
				local n = tonumber(number()) or 0
				return format(math.floor(n + 0.5))
			end
		end
		return Element.new("TextLabel", {
			Size = if p.autoWidth then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0),
			AutomaticSize = if p.autoWidth then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
			TextWrapped = not p.autoWidth,
			RichText = p.richText == true,
			Text = display,
			MaxVisibleGraphemes = visible,
			Visible = h:ref("visible"),
			TextXAlignment = function()
				return ALIGN[align()] or Enum.TextXAlignment.Left
			end,
			Tags = {
				"ui-text" :: any,
				function()
					local name = variant()
					check(name)
					return "ui-text-variant-" .. name
				end,
			},
		})
	end,
}

function Text.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Text
