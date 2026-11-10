--!strict
--[[
	ToggleGroup: a row of toggles where one (or several) can be picked: filter
	chips, a tab bar, a 1 to 5 vote.

		ToggleGroup.new({
			items = { "House", "Techno", { value = "hiphop", text = "Hip hop" } },
			type = "single",       -- single | multiple
			value = "House",       -- single: a value or false; multiple: a list
			required = false,      -- single: picking the picked item again keeps it
			variant = "default",   -- default | outline | line (the Toggle looks)
			size = "md",           -- sm | md | lg
			orientation = "horizontal", -- horizontal | vertical
			gap = "Space1",
			scroll = false,        -- a row too long for its room scrolls sideways, its edges
			                       -- fading; the picked item is brought into view (Tabs: on)
			disabled = false,
			visible = true,
			onValueChange = function(value, group) end,
			Parent = header,
		})
		group:select("Techno")

	An item is a value (a string or number, shown as its text) or a table:
	{ value, text?, icon?, children?, disabled? }. An item is a toggle with a slot (ADR 0042):
	its icon, text and children sit in a row and take its colours (Toggle.slot); with an icon
	or children and no text, it shows no text.

	With scroll, the row sits in a ScrollArea (group.scroller) as wide as its room and as tall as
	its items. A player drags it on touch; a controller's D-pad and the keyboard's arrows move
	through the items and the area follows the selection; picking an item any way (a press,
	LB / RB in Tabs, game code) scrolls it into view.

	State keys: value, variant, size, disabled, visible.
	Events: "select" with the value picked, for Lucy.useUiSound.
	group.items holds the item buttons, in order.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local ScrollArea = require(script.Parent.ScrollArea)
local Toggle = require(script.Parent.Toggle)

local ToggleGroup = {}

export type Item = {
	value: any,
	text: string,
	icon: any,
	children: any,
	disabled: boolean,
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
		Toggle.check(h:get("variant"), h:get("size"))
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
			Toggle.check(v, s)
			return Toggle.tags(v, s)
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
			local function off(): boolean
				return item.disabled or disabled()
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
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = h:ref("visible"),
			Tags = { "ui-toggle-group" },
			Component.list({
				FillDirection = direction,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = Component.space(h.app, p.gap or "Space1", 0),
			}) :: any,
		})
		for _, button in buttons do
			button.Parent = frame
		end
		if not p.scroll or direction ~= Enum.FillDirection.Horizontal then
			return frame
		end

		-- A row too long for its room: it scrolls sideways, as tall as its items
		local height = Reactive.ref(0)
		local area = ScrollArea.new({
			app = h.app,
			direction = "horizontal",
			scrollbar = "scroll",
			visible = h:ref("visible"),
			size = function(): UDim2
				return UDim2.new(1, 0, 0, height())
			end,
			children = { frame },
		})
		h.scroller = area
		local scroller = area.frame :: ScrollingFrame
		-- Side effects of the engine's layout: the row's height, in the area's own units
		local function measure()
			local scale = Scroll.scaleOf(scroller)
			height(math.ceil(frame.AbsoluteSize.Y / (if scale > 0 then scale else 1)))
		end
		measure()
		local connection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		Reactive.onCleanup(function()
			connection:Disconnect()
		end)
		-- The picked item comes into view, however it was picked
		local function reveal()
			if multiple then
				return
			end
			local picked = Reactive.untrack(value)
			for index, item in items do
				if item.value == picked then
					Scroll.reveal(buttons[index])
				end
			end
		end
		Reactive.watch(value, function()
			task.defer(reveal)
		end)
		task.defer(reveal)
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
		if not entry or entry.disabled then
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
