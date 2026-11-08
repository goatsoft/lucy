--!strict
--[[
	Text: headings, body copy and labels.

		Text.new({ text = "Turf Heist", variant = "h1", align = "center" })

	variant: h1 | h2 | h3 | h4 | p | lead | large | small | muted | label
	align:   left | center | right
	autoWidth = true sizes to the text instead of filling the parent's width.
	reveal = 30 types the text out, 30 characters a second (true: Text.REVEAL_RATE), and again
	from the start whenever it changes. The whole text is laid out from the start, so words never
	jump to the next line as they appear. text:skipReveal() shows the rest at once;
	text.Revealed (a Signal) fires when it is all out.

	State keys: text, variant, align, visible, revealing (read only: typing out now).
]]

local Animate = require(script.Parent.Parent.Core.Animate)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Signal = require(script.Parent.Parent.Core.Signal)

local Text = {}

-- Characters a second for reveal = true
Text.REVEAL_RATE = 40

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

-- How many characters a reader sees: rich text tags take none, an entity takes one
local ENTITIES = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }
local function visibleLength(text: string, rich: boolean): number
	if rich then
		text = text:gsub("<[^>]*>", ""):gsub("&(%a+);", function(name)
			return ENTITIES[name]
		end)
	end
	return utf8.len(text) or #text
end

-- The reveal: a count of characters shown (-1 all), stepped on Animate's driver
local function useReveal(h: any, rate: number): Reactive.Ref<number>
	local shown = Reactive.ref(-1)
	local revealed = Signal.new()
	h.Revealed = revealed
	local stopDrive: (() -> ())? = nil
	local function halt()
		if stopDrive then
			stopDrive()
			stopDrive = nil
		end
	end
	local function finish()
		halt()
		shown(-1)
		if h:get("revealing") then
			h:set("revealing", false)
			revealed:Fire(h)
		end
	end
	function h.skipReveal(_self)
		finish()
	end
	Reactive.watch(h:ref("text"), function(value)
		halt()
		local total = visibleLength(tostring(value or ""), h.props.richText == true)
		if total == 0 then
			shown(-1)
			h:set("revealing", false)
			return
		end
		local elapsed = 0
		shown(0)
		h:set("revealing", true)
		stopDrive = Animate.drive(function(dt: number): boolean
			elapsed += dt
			local count = math.floor(elapsed * rate + 1e-6)
			if count >= total then
				stopDrive = nil
				finish()
				return true
			end
			shown(count)
			return false
		end)
	end, { immediate = true })
	Reactive.onCleanup(function()
		halt()
		revealed:DisconnectAll()
	end)
	return shown
end

local function check(variant: string)
	if Text.variants[variant] == nil then
		error(`[Lucy] unknown Text variant "{variant}"`, 0)
	end
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "text",
	defaults = { text = "", variant = "p", align = "left", visible = true, revealing = false },
	rules = Text.rules,
	render = function(h)
		local p: Component.Props = h.props
		check(h:get("variant")) -- an unknown variant fails the mount
		local variant, align = h:ref("variant"), h:ref("align")
		local rate = if p.reveal == true
			then Text.REVEAL_RATE
			elseif type(p.reveal) == "number" then p.reveal
			else nil
		local shown: any = if rate then useReveal(h, rate) else -1
		return Element.new("TextLabel", {
			Size = if p.autoWidth then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0),
			AutomaticSize = if p.autoWidth then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
			TextWrapped = not p.autoWidth,
			RichText = p.richText == true,
			Text = h:ref("text"),
			MaxVisibleGraphemes = shown,
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
