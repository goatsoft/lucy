--!strict
--[[
	Checkbox

		Checkbox.new({
			label = "Mute music",          -- optional; the whole row is the hit area
			children = { ... },   -- optional: after the label in its slot (Slot: strings, handles,
			                      -- instances, builders); Foreground, faded when disabled
			checked = false,
			disabled = false,
			size = "md",          -- sm | md | lg | xl: the box, the label and the row's height
			onCheckedChange = function(checked, checkbox) end,
		})
		checkbox:toggle()

	The row is as tall as a control of the same size (Component.controlTokens), so a checkbox
	lines up with a Button or Switch of its size; the label takes that size's text. The box grows
	with size and with density (md: 16 desktop, 20 touch, 24 console), so it is easy to hit with
	a thumb or a gamepad. State keys: checked, label, disabled, size, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Slot = require(script.Parent.Slot)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Checkbox = {}

Checkbox.sizes = Component.controlSizes

-- The box's side at each size, for each density
Checkbox.boxes = {
	sm = { default = 14, touch = 18, tv = 22 },
	md = { default = 16, touch = 20, tv = 24 },
	lg = { default = 20, touch = 24, tv = 28 },
	xl = { default = 24, touch = 28, tv = 32 },
} :: { [string]: { [string]: number } }

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
	-- The tick and the label follow the size (md is the rules above)
	{
		selector = ".ui-checkbox-check.ui-checkbox-size-sm",
		priority = 5,
		properties = { TextSize = "$TextXs" },
	},
	{
		selector = ".ui-checkbox-check.ui-checkbox-size-lg",
		priority = 5,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-checkbox-check.ui-checkbox-size-xl",
		priority = 5,
		properties = { TextSize = "$TextLg" },
	},
	{
		selector = ".ui-checkbox-label.ui-checkbox-size-sm",
		priority = 5,
		properties = { TextSize = "$TextXs" },
	},
	{
		selector = ".ui-checkbox-label.ui-checkbox-size-lg",
		priority = 5,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-checkbox-label.ui-checkbox-size-xl",
		priority = 5,
		properties = { TextSize = "$TextLg" },
	},
	{ selector = ".ui-checkbox.ui-disabled", priority = 30, properties = { BackgroundTransparency = 0.5 } },
	{ selector = ".ui-checkbox-label.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
}
Checkbox.rules = rules
-- What sits beside the checkbox takes its label's look (ADR 0042)
for _, rule in Slot.beside(".ui-checkbox-root") do
	table.insert(Checkbox.rules, rule)
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "checkbox",
	defaults = { checked = false, label = "", disabled = false, size = "md", visible = true },
	rules = Checkbox.rules,
	render = function(h)
		local p: Component.Props = h.props
		local checked, disabled = h:ref("checked"), h:ref("disabled")
		local label, visible, sizeName = h:ref("label"), h:ref("visible"), h:ref("size")
		Component.checkControlSize(h:get("size"), "Checkbox")
		local density = Composables.useDensity(h.app)
		local function side(): number
			local name = sizeName()
			Component.checkControlSize(name, "Checkbox")
			local list = Checkbox.boxes[name]
			return list[density()] or list.default
		end
		local function sizeTag(): string
			return `ui-checkbox-size-{sizeName()}`
		end
		local function enabled(): boolean
			return not disabled()
		end

		local check = Element.new("TextLabel", {
			Name = "Check",
			Text = "✓",
			Size = UDim2.fromScale(1, 1),
			Visible = checked,
			Tags = function(): { string }
				return { "ui-checkbox-check", sizeTag() }
			end,
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
			Tags = function(): { string }
				local tags = { "ui-checkbox-label", sizeTag() }
				if disabled() then
					table.insert(tags, "ui-disabled")
				end
				return tags
			end,
		})
		h.box, h.check, h.label = box, check, text

		-- The one side effect: telling the owner.
		if p.onCheckedChange then
			Reactive.watch(checked, function(value)
				p.onCheckedChange(value, h)
			end)
		end

		local root = Element.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = function()
				-- As tall as a control of its size, so it lines up with them in a row or a form
				local height = Component.controlTokens[sizeName()].height
				return UDim2.fromOffset(0, math.max(Component.metric(h.app, height), side()))
			end,
			Visible = visible,
			Interactable = enabled,
			Selectable = enabled,
			Tags = { "ui-checkbox-root" :: any, "ui-ring-host", ["ui-disabled"] = disabled },
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
		Slot.fill(root, p.children, { app = h.app, startOrder = 2 })
		return root
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

Component.define(spec)

return Checkbox
