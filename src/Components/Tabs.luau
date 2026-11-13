--!strict
--[[
	Tabs: a tab bar and one panel per tab, showing the picked one.

		Tabs.new({
			items = {
				{ value = "songs", text = "Songs", content = songList },
				{ value = "moves", text = "Moves", content = function() return buildMoves() end },
			},
			value = "songs",       -- the first tab when left out
			variant = "default",   -- default | outline | line (the tab bar's toggle look; line underlines
			                       -- the picked tab) | segmented (a pill as tall as a control of its size)
			size = "md",           -- sm | md | lg | xl (as tall as a Button of the same size)
			gap = "Space2",        -- between the tab bar and the panels
			disabled = false,
			visible = true,
			shoulderButtons = true, -- LB / RB switch tabs while focus is inside
			hints = true,          -- LB and RB shown either side of the bar on a controller (on with
			                       -- shoulderButtons; true keeps them for a game that handles LB / RB)
			scroll = true,         -- a tab bar too long for its room scrolls sideways (drag on
			                       -- touch; the picked tab is brought into view)
			onValueChange = function(value, tabs) end,
			Parent = panel,
		})
		tabs:select("moves")

	A tab's `text`, `icon` and `children` go in its button's slot (ADR 0042, as ToggleGroup).
	`content` is an Instance, a handle, or a function returning either; every
	panel is built at mount and kept, so a tab keeps its scroll position and
	state when the player comes back to it. Tabs fill the width and grow to fit
	the shown panel; put a ScrollArea in a panel for long content. Just a bar (no tab has content)
	with scroll = false fits the bar instead, to sit in a row beside other controls.

	State keys: value, variant, size, disabled, visible.
	Events: "select" with the tab's value (sent by the tab bar), for Lucy.useUiSound.
	tabs.list is the tab bar (a ToggleGroup); tabs.bar is the row it sits in with the LB / RB hints
	(the list itself without hints); tabs.hints is { back, forward } (Kbd), nil without hints;
	tabs.panels maps each value to its panel.
	In a Dialog or Sheet, pass tabs.bar in its header so the bar stays put while the body scrolls;
	LB / RB still switch tabs with focus on the bar (it carries the LucyShoulder attribute).
	The LB / RB hints sit either side of the tabs, centred on them; line tabs hug their words, so
	RB comes right after the last tab rather than at the row's far end.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Kbd = require(script.Parent.Kbd)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local ToggleGroup = require(script.Parent.ToggleGroup)

local Tabs = {}

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "tabs",
	defaults = { value = false, variant = "default", size = "md", disabled = false, visible = true },
	render = function(h)
		local p: Component.Props = h.props
		local items = ToggleGroup.normalize(p.items, "Tabs")
		local value = h:ref("value")
		local variant = h:ref("variant")

		if p.onValueChange then
			Reactive.watch(value, function(new)
				p.onValueChange(new, h)
			end)
		end

		local triggers = {}
		for _, item in items do
			table.insert(triggers, {
				value = item.value,
				text = item.text,
				icon = item.icon,
				children = item.children,
				disabled = item.disabled,
				visible = item.visible,
			})
		end
		local scroll = p.scroll ~= false
		-- With no content in any tab it is just the bar (a picker over one shared view)
		local anyContent = false
		for _, item in items do
			anyContent = anyContent or item.content ~= nil
		end
		-- Just a bar that does not scroll fits its tabs, to sit in a row beside other controls
		local fit = not anyContent and not scroll
		local showHints = if p.hints ~= nil then p.hints == true else p.shoulderButtons ~= false

		local list = ToggleGroup.new({
			app = h.app,
			items = triggers,
			required = true,
			value = value,
			variant = h:ref("variant"),
			size = h:ref("size"),
			disabled = h:ref("disabled"),
			-- A long tab bar scrolls sideways, the picked tab kept in view. Line tabs hug their
			-- words, so the bar is only as wide as them and RB sits right after the last tab.
			scroll = scroll,
			hug = function(): boolean
				return variant() == "line"
			end,
			layoutOrder = if showHints then 2 else 1,
			name = "List",
		})
		h.list = list

		-- LB and RB either side of the bar, shown on a controller only (Kbd hides itself otherwise)
		local bar: GuiObject = list.Instance
		if showHints then
			local back =
				Kbd.new({ app = h.app, gamepad = Enum.KeyCode.ButtonL1, layoutOrder = 1, name = "Back" })
			local forward =
				Kbd.new({ app = h.app, gamepad = Enum.KeyCode.ButtonR1, layoutOrder = 3, name = "Forward" })
			h.hints = { back = back, forward = forward }
			-- Centred on the tabs themselves, not the scrolling bar: the bar keeps room under the tabs
			-- (its scroll bar, a line tab's underline), so each hint sits in a holder with the same
			-- room under it. The holder is there only while its hint is (Kbd hides off a controller).
			local function holder(hint: any, order: number): GuiObject
				if not scroll then
					return hint.Instance
				end
				local shown = Reactive.ref(hint.Instance.Visible)
				local changed = hint.Instance:GetPropertyChangedSignal("Visible"):Connect(function()
					shown(hint.Instance.Visible)
				end)
				h.maid:give(changed)
				local frame = Element.new("Frame", {
					Name = hint.Instance.Name .. "Hint",
					LayoutOrder = order,
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					Visible = shown,
					Element.new("UIPadding", {
						PaddingBottom = function(): UDim
							return UDim.new(0, if list.below then list.below() else 0)
						end,
					}) :: any,
				})
				hint.Instance.Parent = frame
				return frame
			end
			bar = Element.new("Frame", {
				Name = "Bar",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = if fit then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0),
				AutomaticSize = if fit then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
				Component.list({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = Component.space(h.app, "Space2", 0),
				}) :: any,
				holder(back, 1),
				holder(forward, 3),
			})
			-- A bar placed apart from the panels (a Dialog or Sheet's header) is still these tabs':
			-- LB / RB with focus on a tab reach them (InputManager.shoulder)
			bar:SetAttribute("LucyShoulder", h.id)
			if scroll then
				-- The scrolling bar takes the room the hints leave; line tabs only what their words
				-- need (hug), shrinking to scroll when there is less
				local flex = Element.new("UIFlexItem", {
					FlexMode = function(): Enum.UIFlexMode
						local line = variant() == "line"
						return if line then Enum.UIFlexMode.Shrink else Enum.UIFlexMode.Fill
					end,
				})
				flex.Parent = list.Instance
			end
			list.Instance.Parent = bar
		end
		h.bar = bar
		if not showHints then
			bar:SetAttribute("LucyShoulder", h.id)
		end

		local panels: { [any]: Frame } = {}
		local holder = Element.new("Frame", {
			Name = "Panels",
			LayoutOrder = 2,
			Visible = anyContent,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		for index, item in items do
			local itemValue = item.value
			local panel = Element.new("Frame", {
				Name = `Panel{index}`,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = function(): boolean
					return value() == itemValue
				end,
				Tags = { "ui-tabs-panel" },
			})
			local content = item.content
			if type(content) == "function" then
				content = content()
			end
			Component.adopt(panel, { content })
			panel.Parent = holder
			panels[itemValue] = panel
		end
		h.panels = panels

		local root = Element.new("Frame", {
			BackgroundTransparency = 1,
			Size = if fit then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0),
			AutomaticSize = if fit then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			Tags = { "ui-tabs" },
			Component.list({ Padding = Component.space(h.app, p.gap or "Space2", 0) }) :: any,
			holder,
		})
		bar.Parent = root
		return root
	end,
}

function Tabs.new(props: { [string]: any }?)
	local given: { [string]: any } = table.clone(props or {})
	local first = given.items and given.items[1]
	local firstValue = if type(first) == "table" then first.value else first
	if given.value == nil then
		given.value = firstValue
	end
	local handle = Component.mount(spec, given)
	-- A bound ref or app state with nothing in it yet starts on the first tab.
	local current = handle:get("value")
	if (current == nil or current == false) and firstValue ~= nil then
		handle:set("value", firstValue)
	end

	-- The player picked a tab (the tab bar sends "select").
	function handle.select(h, picked: any)
		h.list:select(picked)
	end

	-- LB / RB while focus is inside (InputManager.shoulder): the next or previous
	-- enabled tab, wrapping. Focus follows: into the new panel if it was in the
	-- old one, otherwise to the new tab.
	function handle.shoulder(h, step: number): boolean
		if h.destroyed or h.props.shoulderButtons == false or h:get("disabled") then
			return false
		end
		local entries = h.list.entries
		local count = #entries
		local current = h:get("value")
		local index = 1
		for i, item in entries do
			if item.value == current then
				index = i
			end
		end
		local target: number? = nil
		for offset = 1, count - 1 do
			local i = ((index - 1 + offset * step) % count) + 1
			if not entries[i].disabled then
				target = i
				break
			end
		end
		if not target then
			return false
		end
		local input = h.app.input
		local focused = input:focused()
		local oldPanel: Frame? = h.panels[current]
		local inPanel = focused ~= nil and oldPanel ~= nil and focused:IsDescendantOf(oldPanel)
		local value = entries[target].value
		h.list:select(value)
		local focus: GuiObject = h.list.items[target]
		if inPanel then
			focus = input:selectables(h.panels[value])[1] or focus
		end
		input:focus(focus)
		return true
	end
	return handle
end

return Tabs
