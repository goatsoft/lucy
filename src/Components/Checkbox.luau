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
		selector = ".ui-checkbox::UIStroke",
		priority = 0,
		properties = { Color = "$Input", Thickness = "$StrokeThin" },
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

function Checkbox.new(props: { [string]: any }?)
	local p: Component.Props = props or {}
	local handle = Component.mount({
		kind = "checkbox",
		props = p,
		defaults = { checked = false, label = "", disabled = false, visible = true },
		rules = Checkbox.rules,
		render = function(h)
			local root = Component.create("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Tags = { "ui-checkbox-root" },
			})
			Component.list({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				Parent = root,
			})
			local box = Component.create(
				"Frame",
				{ Name = "Box", LayoutOrder = 1, Tags = { "ui-checkbox" }, Parent = root }
			)
			local check = Component.create("TextLabel", {
				Name = "Check",
				Text = "✓",
				Size = UDim2.fromScale(1, 1),
				Tags = { "ui-checkbox-check" },
				Parent = box,
			})
			local label = Component.create("TextLabel", {
				Name = "Label",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 2,
				Tags = { "ui-checkbox-label" },
				Parent = root,
			})
			h.box, h.check, h.label = box, check, label
			h.maid:give(root.Activated:Connect(function()
				h:toggle()
			end))
			Component.onDensity(h, function()
				local density = h.app.theme:getDensity()
				local size = BOX[density] or BOX.default
				box.Size = UDim2.fromOffset(size, size)
				root.Size = UDim2.fromOffset(0, math.max(Component.metric(h.app, "ControlSm"), size))
			end)
			return root
		end,
		watch = {
			visible = function(h, visible)
				h.Instance.Visible = visible
			end,
			disabled = function(h, disabled)
				h.Instance.Interactable = not disabled
				h.Instance.Selectable = not disabled
				Component.setFlag(h.box, "ui-disabled", disabled)
				Component.setFlag(h.label, "ui-disabled", disabled)
			end,
			label = function(h, label)
				h.label.Text = label
				h.label.Visible = label ~= ""
			end,
			checked = function(h, checked, _, initial)
				h.check.Visible = checked
				Component.setFlag(h.box, "ui-checked", checked)
				if not initial and p.onCheckedChange then
					p.onCheckedChange(checked, h)
				end
			end,
		},
	})

	function handle.toggle(h)
		if h:get("disabled") then
			return
		end
		h:set("checked", not h:get("checked"))
	end
	return handle
end

return Checkbox
