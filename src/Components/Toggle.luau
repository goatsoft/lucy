--!strict
--[[
	Toggle: a button that stays pressed until clicked again (bold, mute, a filter).

		Toggle.new({
			text = "Bold",
			icon = "lucide:bold",  -- optional: before the text (toggle.icon); alone with no text
			pressed = false,
			variant = "default",   -- default | outline | line (an underline when on, as tabs)
			size = "md",           -- sm | md | lg
			disabled = false,
			visible = true,
			children = { icon },   -- optional: after the text in its slot (Slot: strings, handles,
			                       -- instances, builders); alone when there is no text
			onPressedChange = function(pressed, toggle) end,
			Parent = toolbar,
		})
		toggle:toggle()

	A toggle is a box with a slot (ADR 0042): with children, its text (toggle.label) and children sit
	in a row (the Slot frame) and take its colours, hover, on and disabled included (Slot.flow).
	State keys: text, pressed, variant, size, disabled, visible.
	Events: "toggle" with the new value, for Lucy.useUiSound.

	ToggleGroup items share these rules and tags (Toggle.tags, Toggle.check).
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Icon = require(script.Parent.Icon)
local Slot = require(script.Parent.Slot)

local Toggle = {}

Toggle.variants = { "default", "outline", "line" }
Toggle.sizes = { "sm", "md", "lg" }

local ACTIVATED = Element.on("Activated")

local BASE, VARIANT, STATE, SELECTED, DISABLED = 0, 10, 20, 25, 30

Toggle.rules = {
	{
		selector = ".ui-toggle",
		priority = BASE,
		properties = {
			BackgroundColor3 = "$Accent",
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
			BorderSizePixel = 0,
			Size = "$ControlMd",
		},
		transitions = { BackgroundTransparency = TweenInfo.new(0.12), BackgroundColor3 = TweenInfo.new(0.12) },
	},
	{ selector = ".ui-toggle::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-toggle::UIPadding",
		priority = BASE,
		properties = { PaddingLeft = "$Space3", PaddingRight = "$Space3" },
	},
	{
		selector = ".ui-toggle:Hover",
		priority = STATE,
		properties = {
			BackgroundColor3 = "$Muted",
			BackgroundTransparency = 0,
			TextColor3 = "$MutedForeground",
		},
	},
	{
		selector = ".ui-toggle-variant-outline::UIStroke",
		priority = VARIANT,
		properties = {
			Color = "$Input",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-toggle-variant-outline:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$Accent", TextColor3 = "$AccentForeground" },
	},
	{
		selector = ".ui-toggle.ui-selected",
		priority = SELECTED,
		properties = {
			BackgroundColor3 = "$Accent",
			BackgroundTransparency = 0,
			TextColor3 = "$AccentForeground",
		},
	},
	{
		selector = ".ui-toggle-size-sm",
		priority = VARIANT,
		properties = { Size = "$ControlSm", TextSize = "$TextXs" },
	},
	{
		selector = ".ui-toggle-size-sm::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space2", PaddingRight = "$Space2" },
	},
	{
		selector = ".ui-toggle-size-lg",
		priority = VARIANT,
		properties = { Size = "$ControlLg", TextSize = "$TextBase" },
	},
	{
		selector = ".ui-toggle-size-lg::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space4", PaddingRight = "$Space4" },
	},
	-- line: text only, muted until on, with an underline (the Indicator) when on
	{
		selector = ".ui-toggle-variant-line",
		priority = VARIANT,
		properties = { TextColor3 = "$MutedForeground" },
	},
	{
		selector = ".ui-toggle-variant-line::UICorner",
		priority = VARIANT,
		properties = { CornerRadius = UDim.new(0, 0) },
	},
	{
		selector = ".ui-toggle-variant-line:Hover",
		priority = STATE + 1,
		properties = { BackgroundTransparency = 1, TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-toggle-variant-line.ui-selected",
		priority = SELECTED + 1,
		properties = { BackgroundTransparency = 1, TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-toggle-indicator",
		priority = BASE,
		properties = { BackgroundColor3 = "$Primary", BorderSizePixel = 0 },
	},
	{ selector = ".ui-toggle.ui-disabled", priority = DISABLED, properties = { TextTransparency = 0.5 } },
	{
		selector = ".ui-toggle.ui-selected.ui-disabled",
		priority = DISABLED,
		properties = { BackgroundTransparency = 0.5 },
	},
} :: { Component.Rule }

-- The slot row fills the toggle (the Indicator stays out of its layout)
local slotRules: { Component.Rule } = {
	{
		selector = ".ui-toggle-slot",
		priority = 0,
		properties = { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 },
	},
}
-- What sits in the slot takes the toggle's colours (ADR 0042)
for _, rule in Slot.flow(Toggle.rules, " > .ui-toggle-slot > .") do
	table.insert(slotRules, rule)
end
for _, rule in Slot.rules do
	table.insert(slotRules, rule)
end
for _, rule in slotRules do
	table.insert(Toggle.rules, rule)
end

function Toggle.check(variant: string, size: string)
	if not table.find(Toggle.variants, variant) then
		error(`[Lucy] unknown Toggle variant "{variant}" (expected {table.concat(Toggle.variants, ", ")})`, 0)
	end
	if not table.find(Toggle.sizes, size) then
		error(`[Lucy] unknown Toggle size "{size}" (expected {table.concat(Toggle.sizes, ", ")})`, 0)
	end
end

-- One tag list per variant and size pair, shared by every toggle and group item.
local tagLists: { [string]: { string } } = {}
function Toggle.tags(variant: string, size: string): { string }
	local key = variant .. "/" .. size
	local list = tagLists[key]
	if not list then
		list = { "ui-toggle-variant-" .. variant, "ui-toggle-size-" .. size }
		tagLists[key] = list
	end
	return list
end

-- The line variant's underline, shown while `shown` is true (a toggle that is on).
function Toggle.indicator(shown: () -> boolean): Frame
	return Element.new("Frame", {
		Name = "Indicator",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		Visible = shown,
		Tags = { "ui-toggle-indicator" },
	})
end

-- The slot (ADR 0042): an icon, the text and the children in a row that fills a toggle (or a
-- ToggleGroup item), outside the Indicator. Returns the row, the label and the Icon (if any).
function Toggle.slot(app: any, text: any, icon: any, children: any): (Frame, TextLabel, any)
	local function words(): string
		return if type(text) == "function" then text() else text
	end
	local row = Element.new("Frame", {
		Name = "Slot",
		AutomaticSize = Enum.AutomaticSize.X,
		Tags = { "ui-toggle-slot" },
		Element.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}) :: any,
	})
	local mark = nil
	if icon ~= nil then
		mark = Icon.new({ app = app, icon = icon, size = "sm", name = "Icon", layoutOrder = 0 })
		mark.Instance.Parent = row
	end
	local label = Element.new("TextLabel", {
		Name = "Label",
		Text = words,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 1,
		Visible = function(): boolean
			return words() ~= ""
		end,
		Tags = { Slot.TEXT_TAG },
	})
	label.Parent = row
	Slot.fill(row, children, { app = app, startOrder = 1 })
	return row, label, mark
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "toggle",
	defaults = {
		text = "",
		pressed = false,
		variant = "default",
		size = "md",
		disabled = false,
		visible = true,
	},
	rules = Toggle.rules,
	render = function(h)
		local p: Component.Props = h.props
		Toggle.check(h:get("variant"), h:get("size"))
		local variant, size = h:ref("variant"), h:ref("size")
		local pressed, disabled = h:ref("pressed"), h:ref("disabled")
		local function enabled(): boolean
			return not disabled()
		end

		if p.onPressedChange then
			Reactive.watch(pressed, function(value)
				p.onPressedChange(value, h)
			end)
		end

		local root = Element.new("TextButton", {
			AutoButtonColor = false,
			Text = if p.children ~= nil or p.icon ~= nil then "" else h:ref("text"),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = h:ref("visible"),
			Interactable = enabled,
			Selectable = enabled,
			Tags = {
				"ui-toggle" :: any,
				function()
					local v, s = variant(), size()
					Toggle.check(v, s)
					return Toggle.tags(v, s)
				end,
				["ui-selected"] = pressed,
				["ui-disabled"] = disabled,
			},
			[ACTIVATED] = function()
				h:toggle()
			end,
			Toggle.indicator(function(): boolean
				return variant() == "line" and (pressed() :: any) == true
			end) :: any,
		})
		if p.children ~= nil or p.icon ~= nil then
			local row, label, icon = Toggle.slot(h.app, h:ref("text"), p.icon, p.children)
			row.Parent = root
			h.slot, h.label, h.icon = row, label, icon
		end
		return root
	end,
}

function Toggle.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	function handle.toggle(h)
		if h:get("disabled") then
			return
		end
		local pressed = not h:get("pressed")
		h:set("pressed", pressed)
		h:emit("toggle", pressed)
	end
	return handle
end

return Toggle
