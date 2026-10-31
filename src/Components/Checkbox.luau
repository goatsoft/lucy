--!strict
--[[
	Checkbox

		Checkbox.new({
			label = "Mute music",          -- optional; the whole row is the hit area
			checked = false,
			disabled = false,
			onCheckedChange = function(checked, checkbox) end,
		})
		checkbox:toggle()

	The hit area is at least ControlSm tall (32 desktop, 40 touch, 44 console) and
	the box grows with density, so it is easy to hit with a thumb or a gamepad.
	State keys: checked, label, disabled, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Checkbox = {}

local BOX = { default = 16, touch = 20, tv = 24 }

local rules: { Component.Rule } = {
	{
		selector = ".ui-checkbox",
		priority = 0,
		properties = { BackgroundColor3 = "$Background", BorderSizePixel = 0 },
	},
	{ selector = ".ui-checkbox::UICorner", priority = 0, properties = { CornerRadius = "$RadiusSm" } },
	{
		selector = ".ui-checkbox >> .ui-part-ring-corner",
		priority = 1,
		properties = { CornerRadius = "$RadiusSm" },
	},
	{
		selector = ".ui-checkbox::UIStroke",
		priority = 0,
		properties = {
			Color = "$Input",
			Thickness = "$StrokeThin",
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{ selector = ".ui-checkbox.ui-checked", priority = 10, properties = { BackgroundColor3 = "$Primary" } },
	{ selector = ".ui-checkbox.ui-checked::UIStroke", priority = 10, properties = { Color = "$Primary" } },
	{
		selector = ".ui-checkbox-check",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$PrimaryForeground",
			FontFace = "$FontSansBold",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-checkbox-label",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-checkbox.ui-disabled", priority = 30, properties = { BackgroundTransparency = 0.5 } },
	{ selector = ".ui-checkbox-label.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
}
Checkbox.rules = rules

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "checkbox",
	defaults = { checked = false, label = "", disabled = false, visible = true },
	rules = Checkbox.rules,
	render = function(h)
		local p: Component.Props = h.props
		local checked, disabled = h:ref("checked"), h:ref("disabled")
		local label, visible = h:ref("label"), h:ref("visible")
		local density = Composables.useDensity(h.app)
		local function side(): number
			return BOX[density()] or BOX.default
		end
		local function enabled(): boolean
			return not disabled()
		end

		local check = Element.new("TextLabel", {
			Name = "Check",
			Text = "✓",
			Size = UDim2.fromScale(1, 1),
			Visible = checked,
			Tags = { "ui-checkbox-check" },
		})
		local box = Element.new("Frame", {
			Name = "Box",
			LayoutOrder = 1,
			Size = function()
				return UDim2.fromOffset(side(), side())
			end,
			Tags = { "ui-checkbox", ["ui-checked"] = checked, ["ui-disabled"] = disabled },
			check,
			Component.partRing(h.app),
		})
		local text = Element.new("TextLabel", {
			Name = "Label",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 2,
			Text = label,
			Visible = function()
				return label() ~= ""
			end,
			Tags = { "ui-checkbox-label", ["ui-disabled"] = disabled },
		})
		h.box, h.check, h.label = box, check, text

		-- The one side effect: telling the owner.
		if p.onCheckedChange then
			Reactive.watch(checked, function(value)
				p.onCheckedChange(value, h)
			end)
		end

		return Element.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = function()
				return UDim2.fromOffset(0, math.max(Component.metric(h.app, "ControlSm"), side()))
			end,
			Visible = visible,
			Interactable = enabled,
			Selectable = enabled,
			Tags = { "ui-checkbox-root", "ui-ring-host" },
			[Element.on("Activated")] = function()
				h:toggle()
			end,
			Component.list({ -- static: no bindings, so a plain instance
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			}) :: any,
			box,
			text,
		})
	end,
}

function Checkbox.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	function handle.toggle(h)
		if h:get("disabled") then
			return
		end
		local checked = not h:get("checked")
		h:set("checked", checked)
		h:emit("toggle", checked)
	end
	return handle
end

return Checkbox
