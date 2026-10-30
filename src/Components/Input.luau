--[[
	Input: a single-line text field.

		local name = Input.new({
			id = "playerName",
			placeholder = "Display name",
			value = "",
			disabled = false,
			width = UDim.new(1, 0),         -- default fills the parent
			onChange = function(value, input) end,
			onSubmit = function(value, input) end,  -- Enter / gamepad confirm
		})
		app.state:get("ui.playerName.value")

	Height follows the density token ControlMd (36 desktop, 44 touch, 52 console).
	The focus ring shows whenever the field is being typed in.
	State keys: value, placeholder, disabled, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)

local Input = {}

Input.rules = {
	{
		selector = ".ui-input",
		priority = 0,
		properties = {
			BackgroundColor3 = "$Background",
			TextColor3 = "$Foreground",
			PlaceholderColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
			BorderSizePixel = 0,
		},
	},
	{ selector = ".ui-input::UICorner", priority = 0, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-input::UIStroke",
		priority = 0,
		properties = {
			Color = "$Input",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	{
		selector = ".ui-input::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space3", PaddingRight = "$Space3" },
	},
	{
		selector = ".ui-input.ui-focused::UIStroke",
		priority = 20,
		properties = { Color = "$Ring", Thickness = "$FocusRing" },
	},
	{
		selector = ".ui-input.ui-disabled",
		priority = 30,
		properties = { TextTransparency = 0.5, BackgroundTransparency = 0.5 },
	},
}

function Input.new(props: { [string]: any }?)
	local p = props or {}

	local handle = Component.mount({
		kind = "input",
		props = p,
		defaults = { value = "", placeholder = "", disabled = false, visible = true },
		rules = Input.rules,
		render = function(h)
			local box = Component.create("TextBox", {
				ClearTextOnFocus = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Tags = { "ui-input" },
			})
			h.maid:give(box:GetPropertyChangedSignal("Text"):Connect(function()
				-- Signals may be deferred, so compare with state rather than flag our own writes.
				if box.Text == h:get("value") then
					return
				end
				h:set({ value = box.Text })
				if p.onChange then
					p.onChange(box.Text, h)
				end
			end))
			h.maid:give(box.Focused:Connect(function()
				Component.setFlag(box, "ui-focused", true)
			end))
			h.maid:give(box.FocusLost:Connect(function(enterPressed)
				Component.setFlag(box, "ui-focused", false)
				if enterPressed and p.onSubmit then
					p.onSubmit(box.Text, h)
				end
			end))
			Component.onDensity(h, function()
				local width = p.width or UDim.new(1, 0)
				box.Size = UDim2.new(width.Scale, width.Offset, 0, Component.metric(h.app, "ControlMd"))
			end)
			return box
		end,
		update = function(h, state)
			local box = h.Instance
			if box.Text ~= state.value then
				box.Text = state.value
			end
			box.PlaceholderText = state.placeholder
			box.TextEditable = not state.disabled
			box.Interactable = not state.disabled
			box.Visible = state.visible
			Component.setFlag(box, "ui-disabled", state.disabled)
		end,
	})

	-- Focus the field from code (opens the keyboard on touch).
	function handle.focus(h)
		h.Instance:CaptureFocus()
	end
	return handle
end

return Input
