--!strict
--[[
	ToggleGroup: a row of toggles where one (or several) can be picked: filter
	chips, a tab bar, a 1 to 5 vote.

		ToggleGroup.new({
			items = { "House", "Techno", { value = "hiphop", text = "Hip hop" } },
			type = "single",       -- single | multiple
			value = "House",       -- single: a value or false; multiple: a list
			required = false,      -- single: picking the picked item again keeps it
			variant = "default",   -- default | outline | line (the Toggle looks) | segmented (the group
			                       -- is a pill as tall as a control of its size, its items inside)
			size = "md",           -- sm | md | lg | xl (as tall as a Button of the same size)
			orientation = "horizontal", -- horizontal | vertical
			gap = "Space1",
			scroll = false,        -- a row too long for its room scrolls sideways, its edges
			                       -- fading; the picked item is brought into view (Tabs: on)
			hug = false,           -- with scroll: only as wide as the items (a boolean, ref or getter)
			disabled = false,
			visible = true,
			onValueChange = function(value, group) end,
			Parent = header,
		})
		group:select("Techno")

	An item is a value (a string or number, shown as its text) or a table:
	{ value, text?, icon?, children?, disabled?, visible? }. An item is a toggle with a slot
	(ADR 0042): its icon, text and children sit in a row and take its colours (Toggle.slot);
	with an icon or children and no text, it shows no text. `visible` (a boolean, ref or
	getter) shows or hides the item as it changes: a hidden item leaves the row and can't be
	picked, so a group can offer an item only some of the time without being made again.

	With scroll, the row sits in a ScrollArea (group.scroller) as wide as its room and as tall as
	its items, plus group.below() under them (the room kept for the scroll bar and a line tab's
	underline). With hug it is only as wide as its items: give it a UIFlexItem Shrink in a row so
	it still scrolls once the room runs out, and what follows it sits right after it. A player drags it on touch; a controller's D-pad and the keyboard's arrows move
	through the items and the area follows the selection; picking an item any way (a press,
	LB / RB in Tabs, game code) scrolls it into view.

	State keys: value, variant, size, disabled, visible.
	Events: "select" with the value picked, for Lucy.useUiSound.
	group.items holds the item buttons, in order.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local ScrollArea = require(script.Parent.ScrollArea)
local Toggle = require(script.Parent.Toggle)

local ToggleGroup = {}

-- The Toggle looks, and segmented: the group's own pill round toggles in the default look
ToggleGroup.variants = { "default", "outline", "line", "segmented" }

function ToggleGroup.check(variant: string, size: string)
	if not table.find(ToggleGroup.variants, variant) then
		error(
			`[Lucy] unknown ToggleGroup variant "{variant}" (expected {table.concat(
				ToggleGroup.variants,
				", "
			)})`,
			0
		)
	end
	Component.checkControlSize(size, "ToggleGroup")
end

-- The look an item takes in a group of `variant`
local function itemVariant(variant: string): string
	return if variant == "segmented" then "default" else variant
end

export type Item = {
	value: any,
	text: string,
	icon: any,
	children: any,
	disabled: boolean,
	visible: any, -- a boolean, ref or getter
	content: any,
}

-- Turns the `items` prop into tables. Shared by Tabs and RadioGroup.
function ToggleGroup.normalize(items: { any }?, what: string): { Item }
	local list: { Item } = {}
	local source: { any } = items or {}
	for _, entry in source do
		local item: { [string]: any } = if type(entry) == "table" then entry else { value = entry }
		if item.value == nil then
			error(`[Lucy] {what} item needs a value`, 0)
		end
		table.insert(list, {
			value = item.value,
			text = item.text or item.label or (if item.children ~= nil or item.icon ~= nil
				then ""
				else tostring(item.value)),
			icon = item.icon,
			children = item.children,
			disabled = item.disabled == true,
			visible = if item.visible == nil then true else item.visible,
			content = item.content,
		})
	end
	return list
end

local ACTIVATED = Element.on("Activated")
local DIRECTION = {
	horizontal = Enum.FillDirection.Horizontal,
	vertical = Enum.FillDirection.Vertical,
}

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "toggle-group",
	ruleKey = "toggle", -- the items are toggles
	defaults = { value = false, variant = "default", size = "md", disabled = false, visible = true },
	rules = Toggle.rules,
	render = function(h)
		local p: Component.Props = h.props
		ToggleGroup.check(h:get("variant"), h:get("size"))
		local multiple = p.type == "multiple"
		local direction = DIRECTION[p.orientation or "horizontal"]
		if not direction then
			error(`[Lucy] unknown ToggleGroup orientation "{p.orientation}" (horizontal or vertical)`, 0)
		end
		local disabled = h:ref("disabled")
		-- A list is changed in place, which its key alone does not report, so a
		-- multiple group follows a snapshot of the whole list.
		local value: () -> any = h:ref("value")
		if multiple then
			local state = h.app.state
			local segments = state:_segments(h.path .. ".value")
			value = Reactive.computed(function(): any
				return state:_tracked(segments)
			end)
		end
		local variant, size = h:ref("variant"), h:ref("size")
		local function tags(): { string }
			local v, s = variant(), size()
			ToggleGroup.check(v, s)
			return Toggle.tags(itemVariant(v), s)
		end
		-- Segmented: the group draws the pill, as tall as a control of its size in a row
		local function segmented(): boolean
			return variant() == "segmented"
		end
		local row = direction == Enum.FillDirection.Horizontal
		local function fills(): boolean
			return row and segmented()
		end
		local heights: { [string]: () -> number } = {}
		for _, name in Component.controlSizes do
			heights[name] = Composables.useMetric(h.app, Component.controlTokens[name].height)
		end

		if p.onValueChange then
			Reactive.watch(value, function(new)
				p.onValueChange(new, h)
			end)
		end

		local items = ToggleGroup.normalize(p.items, "ToggleGroup")
		local buttons: { TextButton } = {}
		for index, item in items do
			local itemValue = item.value
			local selected = if multiple
				then function(): boolean
					local list = value()
					return type(list) == "table" and table.find(list, itemValue) ~= nil
				end
				else function(): boolean
					return value() == itemValue
				end
			local function shown(): boolean
				return Reactive.toValue(item.visible) ~= false
			end
			local function off(): boolean
				return item.disabled or disabled() or not shown()
			end
			local function enabled(): boolean
				return not off()
			end
			local button = Element.new("TextButton", {
				Name = `Item{index}`,
				LayoutOrder = index,
				AutoButtonColor = false,
				Text = if item.children ~= nil or item.icon ~= nil then "" else item.text,
				AutomaticSize = Enum.AutomaticSize.X,
				Visible = shown,
				Interactable = enabled,
				Selectable = enabled,
				Tags = { "ui-toggle" :: any, tags, ["ui-selected"] = selected, ["ui-disabled"] = off },
				[ACTIVATED] = function()
					h:select(itemValue)
				end,
				Toggle.indicator(function(): boolean
					return variant() == "line" and (selected :: any)() == true
				end) :: any,
			})
			if item.children ~= nil or item.icon ~= nil then
				local row = Toggle.slot(h.app, item.text, item.icon, item.children)
				row.Parent = button
			end
			buttons[index] = button
		end
		h.items = buttons
		h.entries = items

		local frame = Element.new("Frame", {
			BackgroundTransparency = function(): number
				return if segmented() then 0 else 1
			end,
			Size = function(): UDim2
				if fills() then
					local height = heights[size()]
					return UDim2.fromOffset(0, if height then height() else 0)
				end
				return UDim2.fromOffset(0, 0)
			end,
			AutomaticSize = function(): Enum.AutomaticSize
				return if fills() then Enum.AutomaticSize.X else Enum.AutomaticSize.XY
			end,
			Visible = h:ref("visible"),
			Tags = {
				"ui-toggle-group" :: any,
				["ui-toggle-group-segmented"] = segmented,
				["ui-toggle-group-fill"] = fills,
			},
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = direction,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				-- Line tabs have no side padding (their words and underline line up with the content's
				-- edge), so they keep a wider gap between them
				Padding = function(): UDim
					if p.gap == nil and variant() == "line" then
						return Component.space(h.app, "Space6", 24)
					end
					return Component.space(h.app, p.gap or "Space1", 0)
				end,
			}) :: any,
		})
		for _, button in buttons do
			button.Parent = frame
		end
		if not p.scroll or direction ~= Enum.FillDirection.Horizontal then
			return frame
		end

		-- A row too long for its room: it scrolls sideways, as tall as its items. With hug, only as
		-- wide as its items (a UIFlexItem Shrink on it keeps it inside its room), so what sits beside
		-- it in a row sits right after it; otherwise as wide as its room.
		local height = Reactive.ref(0)
		local width = Reactive.ref(0)
		-- The room under the items kept for the scroll bar and a line tab's underline: h.below, for a
		-- row beside it that lines up with the items rather than the whole area
		local below = Reactive.ref(0)
		h.below = below
		local area = ScrollArea.new({
			app = h.app,
			direction = "horizontal",
			scrollbar = "scroll",
			visible = h:ref("visible"),
			size = function(): UDim2
				if Reactive.toValue(p.hug) == true then
					return UDim2.fromOffset(width(), height())
				end
				return UDim2.new(1, 0, 0, height())
			end,
			children = { frame },
		})
		h.scroller = area
		local scroller = area.frame :: ScrollingFrame
		-- Side effects of the engine's layout: the row's height, in the area's own units, plus the
		-- room the scroll bar keeps under it, so nothing at the row's bottom (a line tab's
		-- underline) is cut
		local function measure()
			local scale = Scroll.scaleOf(scroller)
			local unit = if scale > 0 then scale else 1
			below(scroller.ScrollBarThickness + Toggle.INDICATOR_DROP)
			height(math.ceil(frame.AbsoluteSize.Y / unit) + below())
			width(math.ceil(frame.AbsoluteSize.X / unit))
		end
		measure()
		local connection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		Reactive.onCleanup(function()
			connection:Disconnect()
		end)
		-- The picked item comes into view, however it was picked: in the row's own scroller only,
		-- so a page the row sits in stays where the player scrolled it
		local function reveal()
			if multiple then
				return
			end
			local picked = Reactive.untrack(value)
			for index, item in items do
				if item.value == picked then
					Scroll.reveal(buttons[index], nil, scroller)
				end
			end
		end
		Reactive.watch(value, function()
			task.defer(reveal)
		end)
		task.defer(reveal)
		-- And again when its window changes size: a bar made before it was on screen (a closed
		-- dialog) has nothing to scroll until it is laid out, and a phone can turn. Not for the
		-- fraction of a pixel a scaled window wobbles by as a page around it scrolls.
		local window = scroller.AbsoluteWindowSize
		local resized = scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
			local now = scroller.AbsoluteWindowSize
			if math.abs(now.X - window.X) < 0.5 and math.abs(now.Y - window.Y) < 0.5 then
				return
			end
			window = now
			task.defer(reveal)
		end)
		Reactive.onCleanup(function()
			resized:Disconnect()
		end)
		return area.Instance
	end,
}

function ToggleGroup.new(props: { [string]: any }?)
	local given: { [string]: any } = table.clone(props or {})
	local multiple = given.type == "multiple"
	if given.type ~= nil and given.type ~= "single" and not multiple then
		error(`[Lucy] unknown ToggleGroup type "{given.type}" (single or multiple)`, 2)
	end
	if multiple and given.value == nil then
		given.value = {}
	end
	local handle = Component.mount(spec, given)

	-- The player picked `value`: single sets it (or clears it unless required),
	-- multiple adds or removes it. Ignored while the group or the item is disabled.
	function handle.select(h, picked: any)
		if h.destroyed or h:get("disabled") then
			return
		end
		local entry: Item? = nil
		for _, item in h.entries do
			if item.value == picked then
				entry = item
				break
			end
		end
		if not entry or entry.disabled or Reactive.toValue(entry.visible) == false then
			return
		end
		if multiple then
			local current = h:get("value")
			local list = {}
			for _, item in h.entries do
				local on = type(current) == "table" and table.find(current, item.value) ~= nil
				if item.value == picked then
					on = not on
				end
				if on then
					table.insert(list, item.value)
				end
			end
			h:set("value", list)
		elseif h:get("value") == picked then
			if h.props.required then
				return
			end
			h:set("value", false)
		else
			h:set("value", picked)
		end
		h:emit("select", picked)
	end
	return handle
end

return ToggleGroup
