--!strict
--[[
	Select: a button that opens a list of options to pick one from (a region, a
	sort order, a game mode).

		Select.new({
			items = { { value = "eu", label = "Europe" }, { value = "na", label = "North America" }, "Oceania" },
			value = "eu",              -- false for nothing picked yet; an array with multiple
			type = "default",          -- default | check: ticks in front of the labels
			multiple = false,          -- pick several (a check select)
			placeholder = "Region",    -- shown until something is picked
			disabled = false,
			size = UDim2,              -- the trigger's size; full width, control height when left out
			side = "bottom",           -- bottom | top: where the list opens, flipping when there is no room
			align = "start",           -- start | center | end
			onValueChange = function(value, select) end,
			Parent = form,
		})
		select:select("na")  select:open()  select:close()  select:toggle()

	An item is a value (shown as its text) or { value, label?, disabled? }.

	Types: "default" highlights the picked option; "check" draws lucy:check in
	front of the picked one. With multiple = true (a check select) each press
	ticks or unticks an option and the list stays open; the value is an array
	in item order and the button shows the first label and how many more.

	The list floats on the app's overlay layer: under the trigger on mouse,
	keyboard and gamepad, and a drawer from the bottom on touch. On gamepad the
	picked option is selected when it opens, and focus goes back to the trigger
	when it closes. A long list scrolls. The trigger draws lucy:chevron-down
	(see Icon to change it).

	State keys: value, open, placeholder, disabled, visible.
	Events: "select" with the value picked, for Lucy.useUiSound.
	select.items holds one { root, label, check? } per option, in order.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Overlay = require(script.Parent.Parent.Core.Overlay)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local ScrollArea = require(script.Parent.ScrollArea)
local ToggleGroup = require(script.Parent.ToggleGroup)

local Select = {}

local ACTIVATED = Element.on("Activated")

Select.types = { "default", "check" }

-- The width of the tick column in a check select.
local TICK = 24

Select.rules = {
	{
		selector = ".ui-select-trigger",
		priority = 0,
		properties = { BackgroundColor3 = "$Background", BorderSizePixel = 0 },
	},
	{ selector = ".ui-select-trigger::UICorner", priority = 0, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-select-trigger::UIStroke",
		priority = 0,
		properties = {
			Color = "$Input",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-select-trigger::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space3", PaddingRight = "$Space3" },
	},
	{ selector = ".ui-select-trigger:Hover", priority = 10, properties = { BackgroundColor3 = "$Accent" } },
	{ selector = ".ui-select-trigger.ui-open::UIStroke", priority = 20, properties = { Color = "$Ring" } },
	{
		selector = ".ui-select-trigger.ui-disabled",
		priority = 30,
		properties = { BackgroundTransparency = 0.5 },
	},
	{
		selector = ".ui-select-value",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-select-placeholder", priority = 10, properties = { TextColor3 = "$MutedForeground" } },
	{ selector = ".ui-select-value.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
	{
		selector = ".ui-select-content",
		priority = 0,
		properties = { BackgroundColor3 = "$Popover", BorderSizePixel = 0 },
	},
	{ selector = ".ui-select-content::UICorner", priority = 0, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-select-content::UIStroke",
		priority = 0,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-select-content::UIPadding",
		priority = 0,
		properties = {
			PaddingTop = "$Space1",
			PaddingBottom = "$Space1",
			PaddingLeft = "$Space1",
			PaddingRight = "$Space1",
		},
	},
	{
		selector = ".ui-select-drawer::UIPadding",
		priority = 10,
		properties = {
			PaddingTop = "$Space4",
			PaddingBottom = "$Space4",
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
		},
	},
	{ selector = ".ui-select-drawer::UICorner", priority = 10, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-select-option",
		priority = 0,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{ selector = ".ui-select-option::UICorner", priority = 0, properties = { CornerRadius = "$RadiusSm" } },
	{
		selector = ".ui-select-option::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space2", PaddingRight = "$Space2" },
	},
	{ selector = ".ui-select-option:Hover", priority = 10, properties = { BackgroundTransparency = 0 } },
	{ selector = ".ui-select-plain.ui-selected", priority = 10, properties = { BackgroundTransparency = 0 } },
	{
		selector = ".ui-select-option-label",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-select-option-label.ui-disabled",
		priority = 30,
		properties = { TextTransparency = 0.5 },
	},
} :: { Component.Rule }

local spec: Component.Spec = {
	kind = "select",
	defaults = { value = false, open = false, placeholder = "Select", disabled = false, visible = true },
	rules = Select.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local open, disabled = h:ref("open"), h:ref("disabled")
		local kind: string = p._selectKind or "default"
		local multiple: boolean = p._selectMultiple == true
		-- A list is changed in place, which its key alone does not report, so a
		-- multiple select follows a snapshot of the whole list.
		local value: () -> any = h:ref("value")
		if multiple then
			local state = app.state
			local segments = state:_segments(h.path .. ".value")
			value = Reactive.computed(function(): any
				return state:_tracked(segments)
			end)
		end
		local placeholder = h:ref("placeholder")
		local height = Composables.useMetric(app, "ControlMd")
		local entries = ToggleGroup.normalize(p.items, "Select")
		h.entries = entries

		local function has(current: any, itemValue: any): boolean
			if multiple then
				return type(current) == "table" and table.find(current, itemValue) ~= nil
			end
			return current == itemValue
		end
		-- The picked items, in item order.
		local function picked(): { any }
			local current = value()
			local out = {}
			for _, item in entries do
				if has(current, item.value) then
					table.insert(out, item)
				end
			end
			return out
		end
		local function empty(): boolean
			return #picked() == 0
		end
		local function enabled(): boolean
			return not disabled()
		end

		if p.onValueChange then
			Reactive.watch(value, function(new)
				p.onValueChange(new, h)
			end)
		end

		-- The trigger.
		local valueLabel = Element.new("TextLabel", {
			Name = "Value",
			Size = UDim2.new(1, -24, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = function(): string
				local items = picked()
				if #items == 0 then
					return placeholder()
				end
				return if #items == 1 then items[1].text else `{items[1].text} +{#items - 1}`
			end,
			Tags = {
				"ui-select-value" :: any,
				["ui-select-placeholder"] = empty,
				["ui-disabled"] = disabled,
			},
		})
		h.valueLabel = valueLabel
		local caret = Icon.new({
			app = app,
			icon = "lucy:chevron-down",
			size = "sm",
			variant = "muted",
			name = "Caret",
		})
		caret.Instance.AnchorPoint = Vector2.new(1, 0.5)
		caret.Instance.Position = UDim2.fromScale(1, 0.5)
		h.caret = caret

		local given: UDim2? = p.size
		local trigger = Element.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = if given
				then given
				else function(): UDim2
					return UDim2.new(1, 0, 0, height())
				end,
			Interactable = enabled,
			Selectable = enabled,
			Visible = h:ref("visible"),
			Tags = { "ui-select-trigger" :: any, ["ui-open"] = open, ["ui-disabled"] = disabled },
			[ACTIVATED] = function()
				h:click()
			end,
			valueLabel,
		})
		caret.Instance.Parent = trigger

		-- The list.
		local overlayRef: Reactive.Ref<Overlay.Overlay?> = Reactive.ref(nil :: Overlay.Overlay?)
		local function isDrawer(): boolean
			local overlay = overlayRef()
			return overlay ~= nil and overlay.presentation() == "drawer"
		end
		-- The content's own padding, top and bottom, as the rules set it.
		local padSmall = Component.space(app, "Space1", 4).Offset
		local padLarge = Component.space(app, "Space4", 16).Offset
		local rows = {}
		local listFrame = Element.new("Frame", {
			Name = "Options",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Component.list({ Padding = UDim.new(0, 2) }) :: any,
		})
		for index, item in entries do
			local itemValue = item.value
			local function isPicked(): boolean
				return has(value(), itemValue)
			end
			local function off(): boolean
				return item.disabled == true
			end
			local function on(): boolean
				return not off()
			end
			local check = nil
			if kind == "check" then
				check = Icon.new({
					app = app,
					icon = "lucy:check",
					size = "sm",
					name = "Check",
					visible = isPicked,
				})
				check.Instance.AnchorPoint = Vector2.new(0, 0.5)
				check.Instance.Position = UDim2.fromScale(0, 0.5)
			end
			local indent = if check then TICK else 0
			local label = Element.new("TextLabel", {
				Name = "Label",
				Position = UDim2.fromOffset(indent, 0),
				Size = UDim2.new(1, -indent, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = item.text,
				Tags = { "ui-select-option-label" :: any, ["ui-disabled"] = off },
			})
			local root = Element.new("TextButton", {
				Name = `Option{index}`,
				LayoutOrder = index,
				Text = "",
				AutoButtonColor = false,
				Size = function(): UDim2
					return UDim2.new(1, 0, 0, height())
				end,
				Interactable = on,
				Selectable = on,
				Tags = {
					"ui-select-option" :: any,
					if check then "ui-select-checks" else "ui-select-plain",
					["ui-selected"] = isPicked,
					["ui-disabled"] = off,
				},
				[ACTIVATED] = function()
					h:select(itemValue)
				end,
				label,
			})
			if check then
				check.Instance.Parent = root
			end
			root.Parent = listFrame
			rows[index] = { root = root, label = label, check = check }
		end
		h.items = rows

		local list = ScrollArea.new({
			app = app,
			name = "List",
			scrollbar = "auto",
			maxHeight = function(): number
				local overlay = overlayRef()
				if not overlay then
					return math.huge
				end
				local pad = if isDrawer() then padLarge else padSmall
				return math.max(0, overlay.maxHeight() - pad * 2 - overlay.safeBottom())
			end,
			children = { listFrame },
		})
		h.list = list

		local content = Element.new("Frame", {
			Name = "Content",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Active = true,
			Tags = { "ui-select-content" :: any, ["ui-select-drawer"] = isDrawer },
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			list.Instance,
			-- Room for a phone's home bar under a drawer; the background still runs to the edge.
			Element.new("Frame", {
				Name = "SafeArea",
				LayoutOrder = 2147483647, -- last, whatever order the list was given
				BackgroundTransparency = 1,
				Size = function(): UDim2
					local overlay = overlayRef()
					return UDim2.new(1, 0, 0, if overlay then overlay.safeBottom() else 0)
				end,
				Visible = function(): boolean
					local overlay = overlayRef()
					return isDrawer() and overlay ~= nil and overlay.safeBottom() > 0
				end,
			}),
		}) :: Frame
		h.content = content

		local overlay = Overlay.use(app, {
			open = open,
			content = content,
			presentation = "auto",
			prefer = "popup",
			anchor = trigger,
			side = p.side,
			align = p.align,
			name = "SelectList",
			tags = { "ui-select-overlay" },
			id = h.id,
			defaultFocus = function()
				local current = value()
				local first
				for index, item in entries do
					if not item.disabled then
						if has(current, item.value) then
							return rows[index].root
						end
						first = first or rows[index].root
					end
				end
				return first
			end,
		})
		overlayRef(overlay)
		h.presentation = overlay.presentation
		Component.claimSelection(app, overlay.root)

		-- A disabled select closes and cannot open.
		Reactive.watch(disabled, function(off)
			if off and Reactive.peek(open) then
				open(false)
			end
		end)

		return trigger
	end,
}

function Select.new(props: { [string]: any }?)
	local given: { [string]: any } = table.clone(props or {})
	local multiple = given.multiple == true
	local kind = given.type or (if multiple then "check" else "default")
	if not table.find(Select.types, kind) then
		error(`[Lucy] unknown Select type "{tostring(kind)}" ({table.concat(Select.types, " or ")})`, 2)
	end
	if multiple and kind ~= "check" then
		error(`[Lucy] a Select with multiple = true is a check select (type "check")`, 2)
	end
	if multiple and given.value == nil then
		given.value = {}
	end
	-- Read by render (the spec is shared, so it goes through the props).
	given._selectKind, given._selectMultiple = kind, multiple
	local handle = Component.mount(spec, given)
	Component.clickable(handle)
	function handle.open(h)
		if not h:get("disabled") then
			h:set("open", true)
		end
	end
	function handle.close(h)
		h:set("open", false)
	end
	function handle.toggle(h)
		if h:get("open") then
			h:close()
		else
			h:open()
		end
	end
	-- The player picked `value`: set it, report it and close. Ignored for a
	-- disabled option or select; picking the current value just closes. With
	-- multiple it ticks or unticks the option and the list stays open.
	function handle.select(h, picked: any)
		if h.destroyed or h:get("disabled") then
			return
		end
		for _, item in h.entries do
			if item.value == picked then
				if item.disabled then
					return
				end
				if multiple then
					local current = h:get("value")
					local list = {}
					for _, entry in h.entries do
						local on = type(current) == "table" and table.find(current, entry.value) ~= nil
						if entry.value == picked then
							on = not on
						end
						if on then
							table.insert(list, entry.value)
						end
					end
					h:set("value", list)
					h:emit("select", picked)
					return
				end
				if h:get("value") ~= picked then
					h:set("value", picked)
					h:emit("select", picked)
				end
				h:close()
				return
			end
		end
	end
	handle.Activated:Connect(function()
		handle:toggle()
	end)
	return handle
end

return Select
