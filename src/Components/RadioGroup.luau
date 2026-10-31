--!strict
--[[
	RadioGroup: a list of options where exactly one can be picked, for forms and
	settings (difficulty, region, a report reason).

		RadioGroup.new({
			items = { { value = "easy", label = "Easy" }, { value = "hard", label = "Hard" }, "Expert" },
			value = "easy",          -- false for nothing picked yet
			orientation = "vertical", -- vertical | horizontal
			gap = "Space2",
			disabled = false,
			visible = true,
			onValueChange = function(value, group) end,
			Parent = form,
		})
		group:select("hard")

	An item is a value (shown as its text) or { value, label?, disabled? }. Once
	something is picked the player can change it but not clear it.

	Each row's hit area is at least ControlSm tall and the circle grows with
	density, like Checkbox.
	State keys: value, disabled, visible.
	Events: "select" with the value picked, for Lucy.useUiSound.
	group.items holds one { root, circle, dot, label } per option, in order.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local ToggleGroup = require(script.Parent.ToggleGroup)

local RadioGroup = {}

local CIRCLE = { default = 16, touch = 20, tv = 24 }
local ACTIVATED = Element.on("Activated")
local DIRECTION = {
	horizontal = Enum.FillDirection.Horizontal,
	vertical = Enum.FillDirection.Vertical,
}

RadioGroup.rules = {
	{
		selector = ".ui-radio",
		priority = 0,
		properties = { BackgroundColor3 = "$Background", BorderSizePixel = 0 },
	},
	{ selector = ".ui-radio::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-radio::UIStroke",
		priority = 0,
		properties = { Color = "$Input", Thickness = "$StrokeThin" },
	},
	{ selector = ".ui-radio.ui-selected::UIStroke", priority = 10, properties = { Color = "$Primary" } },
	{
		selector = ".ui-radio-dot",
		priority = 0,
		properties = { BackgroundColor3 = "$Primary", BorderSizePixel = 0 },
	},
	{ selector = ".ui-radio-dot::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-radio-label",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-radio.ui-disabled", priority = 30, properties = { BackgroundTransparency = 0.5 } },
	{ selector = ".ui-radio-dot.ui-disabled", priority = 30, properties = { BackgroundTransparency = 0.5 } },
	{ selector = ".ui-radio-label.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
} :: { Component.Rule }

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "radio-group",
	defaults = { value = false, disabled = false, visible = true },
	rules = RadioGroup.rules,
	render = function(h)
		local p: Component.Props = h.props
		local direction = DIRECTION[p.orientation or "vertical"]
		if not direction then
			error(`[Lucy] unknown RadioGroup orientation "{p.orientation}" (vertical or horizontal)`, 0)
		end
		local value, disabled = h:ref("value"), h:ref("disabled")
		local density = Composables.useDensity(h.app)
		local function side(): number
			return CIRCLE[density()] or CIRCLE.default
		end
		local function circleSize(): UDim2
			return UDim2.fromOffset(side(), side())
		end
		local function rowSize(): UDim2
			return UDim2.fromOffset(0, math.max(Component.metric(h.app, "ControlSm"), side()))
		end

		if p.onValueChange then
			Reactive.watch(value, function(new)
				p.onValueChange(new, h)
			end)
		end

		local entries = ToggleGroup.normalize(p.items, "RadioGroup")
		local rows = {}
		local frame = Element.new("Frame", {
			BackgroundTransparency = 1,
			Size = if direction == Enum.FillDirection.Vertical
				then UDim2.fromScale(1, 0)
				else UDim2.fromOffset(0, 0),
			AutomaticSize = if direction == Enum.FillDirection.Vertical
				then Enum.AutomaticSize.Y
				else Enum.AutomaticSize.XY,
			Visible = h:ref("visible"),
			Tags = { "ui-radio-group" },
			Component.list({
				FillDirection = direction,
				Padding = Component.space(h.app, p.gap or "Space2", 0),
			}) :: any,
		})
		for index, item in entries do
			local itemValue = item.value
			local function picked(): boolean
				return value() == itemValue
			end
			local function off(): boolean
				return item.disabled or disabled()
			end
			local function enabled(): boolean
				return not off()
			end
			local dot = Element.new("Frame", {
				Name = "Dot",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.5),
				Visible = picked,
				Tags = { "ui-radio-dot", ["ui-disabled"] = off },
			})
			local circle = Element.new("Frame", {
				Name = "Circle",
				LayoutOrder = 1,
				Size = circleSize,
				Tags = { "ui-radio", ["ui-selected"] = picked, ["ui-disabled"] = off },
				dot,
				Component.partRing(h.app),
			})
			local label = Element.new("TextLabel", {
				Name = "Label",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Text = item.text,
				Tags = { "ui-radio-label", ["ui-disabled"] = off },
			})
			local root = Element.new("TextButton", {
				Name = `Option{index}`,
				LayoutOrder = index,
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = rowSize,
				Interactable = enabled,
				Selectable = enabled,
				Tags = { "ui-radio-option", "ui-ring-host" },
				[ACTIVATED] = function()
					h:select(itemValue)
				end,
				Component.list({ -- static: no bindings, so a plain instance
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
				}) :: any,
				circle,
				label,
			})
			root.Parent = frame
			rows[index] = { root = root, circle = circle, dot = dot, label = label }
		end
		h.items = rows
		h.entries = entries
		return frame
	end,
}

function RadioGroup.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	-- The player picked `value`. Ignored while the group or the option is
	-- disabled, and when it is already the picked one.
	function handle.select(h, picked: any)
		if h.destroyed or h:get("disabled") or h:get("value") == picked then
			return
		end
		for _, item in h.entries do
			if item.value == picked then
				if item.disabled then
					return
				end
				h:set("value", picked)
				h:emit("select", picked)
				return
			end
		end
	end
	return handle
end

return RadioGroup
