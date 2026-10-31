--!strict
--[[
	Input: a text field, on one line or several.

		local name = Input.new({
			id = "playerName",
			placeholder = "Display name",
			value = "",
			disabled = false,
			width = UDim.new(1, 0),         -- default fills the parent
			maxLength = 20,                 -- characters the player can type
			numeric = false,                -- only digits, one leading minus, one point
			multiline = false,              -- wraps; Enter adds a line
			rows = 3,                       -- a multiline field's height in lines
			onChange = function(value, input) end,
			onSubmit = function(value, input) end,  -- Enter / gamepad confirm
		})
		app.state:get("ui.playerName.value")

	Height follows the density token ControlMd (36 desktop, 44 touch, 52 console).
	A multiline field is ControlMd plus a line for each row after the first.
	The focus ring shows whenever the field is being typed in. maxLength and
	numeric apply to what the player types; the value stays a string.
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
			-- Inside the edge, so the focus ring grows inward, never past the field.
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-input::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space3", PaddingRight = "$Space3" },
	},
	{
		selector = ".ui-input-multiline::UIPadding",
		priority = 10,
		properties = { PaddingTop = "$Space2", PaddingBottom = "$Space2" },
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

Input.rows = 3 -- a multiline field's default height in lines
Input.lineHeight = 1.25 -- line height for multiline sizing, times the text size

-- `text` with only what can make a number: digits, one leading minus, one point.
function Input.filterNumber(text: string): string
	local out = table.create(#text)
	local point = false
	for i = 1, #text do
		local c = string.sub(text, i, i)
		local digit = c >= "0" and c <= "9"
		local minus = c == "-" and #out == 0
		local first = c == "." and not point
		if first then
			point = true
		end
		if digit or minus or first then
			table.insert(out, c)
		end
	end
	return table.concat(out)
end

-- `text` cut to `max` characters (UTF-8 aware); invalid UTF-8 is cut by bytes.
local function cut(text: string, max: number): string
	local length = utf8.len(text)
	if length == nil then
		return string.sub(text, 1, max)
	end
	if length <= max then
		return text
	end
	local stop = utf8.offset(text, max + 1)
	return string.sub(text, 1, (stop or #text + 1) - 1)
end

-- What the player typed, with the field's numeric and maxLength rules applied.
function Input.clean(text: string, props: { [string]: any }): string
	if props.numeric then
		text = Input.filterNumber(text)
	end
	local max = props.maxLength
	if type(max) == "number" and max >= 0 then
		text = cut(text, max)
	end
	return text
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "input",
	defaults = { value = "", placeholder = "", disabled = false, visible = true },
	rules = Input.rules,
	render = function(h)
		local p: Component.Props = h.props
		local value, disabled = h:ref("value"), h:ref("disabled")
		local height = Composables.useMetric(h.app, "ControlMd")
		local focused = Reactive.ref(false)
		local width: UDim = p.width or UDim.new(1, 0)
		local multiline = p.multiline == true
		local rows: number = p.rows or Input.rows
		local filtered = p.numeric == true or type(p.maxLength) == "number"
		local theme = h.app.theme
		local function enabled(): boolean
			return not disabled()
		end
		local function fieldHeight(): number
			local base = height()
			if not multiline or rows <= 1 then
				return base
			end
			local size = theme:resolve("TextSm")
			local line = math.ceil((if type(size) == "number" then size else 14) * Input.lineHeight)
			return base + (rows - 1) * line
		end

		return Element.new("TextBox", {
			ClearTextOnFocus = false,
			MultiLine = multiline,
			TextWrapped = multiline,
			ClipsDescendants = multiline,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = if multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
			TextTruncate = if multiline then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
			Size = function()
				return UDim2.new(width.Scale, width.Offset, 0, fieldHeight())
			end,
			Text = value,
			PlaceholderText = h:ref("placeholder"),
			TextEditable = enabled,
			Interactable = enabled,
			Visible = h:ref("visible"),
			Tags = {
				"ui-input" :: any,
				if multiline then "ui-input-multiline" else nil,
				["ui-disabled"] = disabled,
				["ui-focused"] = focused,
			},
			-- Typing writes state. Signals may be deferred, so compare with state
			-- rather than flag our own writes: text that state already holds is ours.
			[Element.changed("Text")] = function(text: string)
				-- Text state already holds came from state (or is ours): leave it,
				-- so the filters apply to typing only.
				if text == value() then
					return
				end
				if filtered then
					-- Put the cleaned text back; that change comes round again clean.
					local clean = Input.clean(text, p)
					if clean ~= text then
						local box = h.Instance
						local cursor = box.CursorPosition
						box.Text = clean
						if cursor > 0 then
							box.CursorPosition = math.min(cursor, #clean + 1)
						end
						return
					end
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
}

function Input.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	-- Focus the field from code (opens the keyboard on touch).
	function handle.focus(h)
		h.Instance:CaptureFocus()
	end
	return handle
end

return Input
