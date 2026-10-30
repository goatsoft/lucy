--!strict
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
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Input = {}

local rules: { Component.Rule } = {
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
Input.rules = rules

function Input.new(props: { [string]: any }?)
	local p: Component.Props = props or {}

	local handle = Component.mount({
		kind = "input",
		props = p,
		defaults = { value = "", placeholder = "", disabled = false, visible = true },
		rules = Input.rules,
		render = function(h)
			local value, disabled = h:ref("value"), h:ref("disabled")
			local height = Composables.useMetric(h.app, "ControlMd")
			local focused = Reactive.ref(false)
			local width: UDim = p.width or UDim.new(1, 0)
			local function enabled(): boolean
				return not disabled()
			end

			return Element.new("TextBox", {
				ClearTextOnFocus = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = function()
					return UDim2.new(width.Scale, width.Offset, 0, height())
				end,
				Text = value,
				PlaceholderText = h:ref("placeholder"),
				TextEditable = enabled,
				Interactable = enabled,
				Visible = h:ref("visible"),
				Tags = { "ui-input", ["ui-disabled"] = disabled, ["ui-focused"] = focused },
				-- Typing writes state. Signals may be deferred, so compare with state
				-- rather than flag our own writes: text that state already holds is ours.
				[Element.changed("Text")] = function(text: string)
					if text == value() then
						return
					end
					value(text)
					if p.onChange then
						p.onChange(text, h)
					end
				end,
				[Element.on("Focused")] = function()
					focused(true)
				end,
				[Element.on("FocusLost")] = (function(enterPressed: boolean)
					focused(false)
					if enterPressed and p.onSubmit then
						p.onSubmit(h.Instance.Text, h)
					end
				end) :: any, -- handlers differ in shape; Element takes any
			})
		end,
	})

	-- Focus the field from code (opens the keyboard on touch).
	function handle.focus(h)
		h.Instance:CaptureFocus()
	end
	return handle
end

return Input
