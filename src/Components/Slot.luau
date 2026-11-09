--!strict
--[[
	Slot: the content inside a component that holds content (a badge, a button, a tab, an
	option), and how that content takes the component's colours (ADR 0042).

		Slot.fill(parent, content, { app = app })
			content: a string (made a Text, tagged ui-slot-text), a handle, an instance, a
			builder (function(parent)) or a list of any of them, in order

		local rules = Slot.flow(Button.rules)
			for each rule that sets text properties, twins one level down: the slot's own words
			(> .ui-slot-text) get its colour, fade, font and size; any Text below (>> .ui-text)
			its colour and fade; any Icon below (>> .ui-icon) the colour and fade as ImageColor3
			and ImageTransparency. Each twin sits 11 above its rule: over Text's and Icon's own
			variants (10), under a game's tone rules (40 and up).

		Slot.beside(".ui-checkbox-root")
			the same for a slot beside a control (a label in a row): Foreground words, faded when
			the root is ui-disabled

		app.theme:addRules("myBadges", Slot.foreground(".ui-badge.my-gold", "$Yellow400", 41))
			a component's colour from a game: the rule and its twins, so its words and icons
			change together

	An untinted icon (a colour picture, ui-icon-untinted) stays white whatever it sits in.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Text = require(script.Parent.Text)

local Slot = {}

-- What a slot's own words take from the component (all of it) and what any text or icon deeper
-- in takes (colour and fade only: a Text keeps its own size)
local OWN = { "TextColor3", "TextTransparency", "FontFace", "TextSize" }
local COLOUR = { "TextColor3", "TextTransparency" }
local TO_IMAGE: { [string]: string } = { TextColor3 = "ImageColor3", TextTransparency = "ImageTransparency" }

Slot.TEXT_TAG = "ui-slot-text"
-- How far a twin sits above the rule it comes from
Slot.LIFT = 11

Slot.rules = {
	{ selector = ".ui-slot-text", priority = 0, properties = { BackgroundTransparency = 1 } },
	{ selector = ".ui-icon.ui-icon-untinted", priority = 100, properties = { ImageColor3 = "$White" } },
} :: { Component.Rule }

local function pick(properties: { [string]: any }, names: { string }): { [string]: any }?
	local out: { [string]: any } = {}
	local any = false
	for _, name in names do
		if properties[name] ~= nil then
			out[name] = properties[name]
			any = true
		end
	end
	return if any then out else nil
end

-- The twins of one rule (none for a rule on a part, ::UICorner, or one that already reaches down)
local function twins(rule: Component.Rule, ownPath: string?): { Component.Rule }
	local selector = rule.selector
	if string.find(selector, "::", 1, true) or string.find(selector, ">", 1, true) then
		return {}
	end
	local properties = rule.properties :: { [string]: any }
	local priority = (rule.priority or 0) + Slot.LIFT
	local out: { Component.Rule } = {}
	local own = pick(properties, OWN)
	if own then
		table.insert(out, {
			selector = selector .. (ownPath or " > .") .. Slot.TEXT_TAG,
			priority = priority,
			properties = own,
		})
	end
	local colour = pick(properties, COLOUR)
	if colour then
		table.insert(out, { selector = selector .. " >> .ui-text", priority = priority, properties = colour })
		local image: { [string]: any } = {}
		for from, value in colour do
			image[TO_IMAGE[from]] = value
		end
		table.insert(out, { selector = selector .. " >> .ui-icon", priority = priority, properties = image })
	end
	return out
end

-- The twins of every rule in `rules`, to add to them. `ownPath` is the way from the component to
-- its slot's words when they are not its direct child (" > .ui-toggle-slot > ."; default " > .")
function Slot.flow(rules: { Component.Rule }, ownPath: string?): { Component.Rule }
	local out: { Component.Rule } = {}
	for _, rule in rules do
		for _, twin in twins(rule, ownPath) do
			table.insert(out, twin)
		end
	end
	return out
end

-- A colour for a component from a game: the rule on `selector` and its twins
function Slot.foreground(selector: string, colour: any, priority: number?): { Component.Rule }
	local rule: Component.Rule =
		{ selector = selector, priority = priority or 40, properties = { TextColor3 = colour } }
	local out = { rule }
	for _, twin in twins(rule) do
		table.insert(out, twin)
	end
	return out
end

-- The rules for a slot beside a control (a checkbox's, switch's or radio's label, a collapsible's
-- header): its words in Foreground, medium, TextSm, as the control's label, faded with
-- `rootSelector`.ui-disabled; and the twins, so a Text or Icon in the slot takes them too
function Slot.beside(rootSelector: string): { Component.Rule }
	local base: { Component.Rule } = {
		{
			selector = rootSelector,
			priority = 0,
			properties = { TextColor3 = "$Foreground", FontFace = "$FontSansMedium", TextSize = "$TextSm" },
		},
		{ selector = rootSelector .. ".ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
	}
	local out = Slot.flow(base)
	for _, rule in Slot.rules do
		table.insert(out, rule)
	end
	return out
end

-- Puts `content` in `parent`, in order after `startOrder`; returns the last LayoutOrder used
export type FillOptions = { app: any?, startOrder: number? }

function Slot.fill(parent: Instance, content: any, options: FillOptions?): number
	local opts: FillOptions = options or {}
	local order = opts.startOrder or 0
	if content == nil then
		return order
	end
	local kind = typeof(content)
	if kind == "string" or kind == "number" then
		local text = Text.new({ app = opts.app, text = tostring(content), autoWidth = true })
		text.Instance:AddTag(Slot.TEXT_TAG)
		return Component.adopt(parent, text, order)
	end
	if kind == "table" and typeof((content :: any).Instance) ~= "Instance" then
		for _, item in ipairs(content) do
			order = Slot.fill(parent, item, { app = opts.app, startOrder = order })
		end
		return order
	end
	return Component.adopt(parent, content, order)
end

return Slot
