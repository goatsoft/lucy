--!strict
--[[
	Select: a button that opens a list of options to pick one from (a region, a
	sort order, a game mode).

		Select.new({
			items = { { value = "eu", label = "Europe" }, { value = "na", label = "North America" }, "Oceania" },
			value = "eu",              -- false for nothing picked yet
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

	The list floats on the app's overlay layer: under the trigger on mouse,
	keyboard and gamepad, and a drawer from the bottom on touch. On gamepad the
	picked option is selected when it opens, and focus goes back to the trigger
	when it closes. A long list scrolls. The trigger draws lucy:chevron-down and
	the picked option lucy:check (see Icon to change them).

	State keys: value, open, placeholder, disabled, visible.
	Events: "select" with the value picked, for Lucy.useUiSound.
	select.items holds one { root, label, check } per option, in order.
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
		local value, open, disabled = h:ref("value"), h:ref("open"), h:ref("disabled")
		local placeholder = h:ref("placeholder")
		local height = Composables.useMetric(app, "ControlMd")
		local entries = ToggleGroup.normalize(p.items, "Select")
		h.entries = entries

		local function picked(): any
			local current = value()
			for _, item in entries do
				if item.value == current then
					return item
				end
			end
			return nil
		end
		local function empty(): boolean
			return picked() == nil
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
				local item = picked()
				return if item then item.text else placeholder()
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
				return value() == itemValue
			end
			local function off(): boolean
				return item.disabled == true
			end
			local function on(): boolean
				return not off()
			end
			local check =
				Icon.new({ app = app, icon = "lucy:check", size = "sm", name = "Check", visible = isPicked })
			check.Instance.AnchorPoint = Vector2.new(1, 0.5)
			check.Instance.Position = UDim2.fromScale(1, 0.5)
			local label = Element.new("TextLabel", {
				Name = "Label",
				Size = UDim2.new(1, -24, 1, 0),
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
				Tags = { "ui-select-option" :: any, ["ui-selected"] = isPicked, ["ui-disabled"] = off },
				[ACTIVATED] = function()
					h:select(itemValue)
				end,
				label,
			})
			check.Instance.Parent = root
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
				return math.max(0, overlay.maxHeight() - pad * 2)
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
			list.Instance,
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
						if item.value == current then
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
	local handle = Component.mount(spec, props)
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
	-- disabled option or select; picking the current value just closes.
	function handle.select(h, picked: any)
		if h.destroyed or h:get("disabled") then
			return
		end
		for _, item in h.entries do
			if item.value == picked then
				if item.disabled then
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
