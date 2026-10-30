--!strict
--[[
	NumberField: a number in a field, with a minus button before it and a plus
	button after it.

		NumberField.new({
			value = 4,
			min = 1,                 -- no limit when left out
			max = 16,
			step = 1,
			disabled = false,
			visible = true,
			placeholder = "",
			format = function(value) return tostring(value) end,
			width = UDim.new(0, 160), -- fills the parent when left out
			onValueChange = function(value, field) end, -- every change
			onValueCommit = function(value, field) end, -- once per press, held arrow or typed number
			Parent = settings,
		})
		field:setValue(8)

	Mouse and touch press the buttons (held, they repeat and speed up), or type
	in the field: the typed number counts when the player presses Enter or
	leaves the field, snapped to the step and kept in min..max; text that is not
	a number puts the value back. On keyboard and gamepad the field is the only
	stop: left and right step it, like a Slider, and confirm starts typing.

	State keys: value, min, max, step, placeholder, disabled, visible.
	Events: "select" with the value, once per change the player made.
	field.field is the Input; field.minus and field.plus are the buttons.
]]

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Input = require(script.Parent.Input)
local InputManager = require(script.Parent.Parent.Core.InputManager)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local NumberField = {}

-- Held, the buttons and arrows move one step at a time, then after this many
-- repeats a 25th of the range per repeat (ten steps when there is no range).
NumberField.fastAfter = 12
NumberField.fastParts = 25
NumberField.fastSteps = 10
NumberField.iconSize = 16
NumberField.fieldWidth = 48 -- the field's least width; it fills what the buttons leave

local rules: { Component.Rule } = {
	{
		selector = ".ui-number-field-step.ui-disabled >> .ui-icon",
		priority = 30,
		properties = { ImageTransparency = 0.5 },
	},
}
NumberField.rules = rules

-- `value` kept in min..max and rounded to a step, counted from min when there is
-- one and from zero when not. No step leaves it unrounded.
function NumberField.snap(value: number, min: number, max: number, step: number?): number
	if max < min then
		max = min
	end
	local v = math.clamp(value, min, max)
	if step and step > 0 then
		local base = if min > -math.huge then min else 0
		-- The small nudge keeps 0.35 / 0.1 (3.4999...) rounding up.
		v = base + math.floor((v - base) / step + 0.5 + 1e-9) * step
		if v > max then
			v -= step
		elseif v < min then
			v += step
		end
		v = tonumber(string.format("%.10g", v)) :: number
	end
	return v
end

-- The value as shown when `format` is left out: whole numbers without a point.
function NumberField.format(value: number): string
	if value == math.floor(value) and math.abs(value) < 1e15 then
		return string.format("%d", value)
	end
	return string.format("%.10g", value)
end

local spec: Component.Spec = {
	kind = "numberField",
	defaults = {
		value = 0,
		min = -math.huge,
		max = math.huge,
		step = 1,
		placeholder = "",
		disabled = false,
		visible = true,
	},
	rules = NumberField.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		-- The buttons wear Button's outline icon look.
		app.theme:addRules("button", Button.rules)
		local value, min, max = h:ref("value"), h:ref("min"), h:ref("max")
		local disabled = h:ref("disabled")
		local format: (number) -> string = p.format or NumberField.format
		local width: UDim = p.width or UDim.new(1, 0)
		local height = Composables.useMetric(app, "ControlMd")

		-- What the player is typing, until it is taken or put back (false: none).
		local draft = Reactive.ref(false :: string | false)
		h._draft = draft
		local text = Reactive.computed({
			get = function(): string
				local typed = draft()
				if typed ~= false then
					return typed :: string
				end
				return format(value())
			end,
			set = function(typed: string)
				draft(typed)
			end,
		})

		local field = Input.new({
			app = app,
			name = "Field",
			numeric = true,
			value = text,
			placeholder = h:ref("placeholder"),
			disabled = disabled,
			width = UDim.new(0, NumberField.fieldWidth),
			layoutOrder = 2,
		})
		local box: TextBox = field.Instance
		box.TextXAlignment = Enum.TextXAlignment.Center
		local flex = Instance.new("UIFlexItem")
		flex.FlexMode = Enum.UIFlexMode.Fill
		flex.Parent = box
		h.field = field

		local focusLost = box.FocusLost:Connect(function()
			h:_commitText()
		end)
		Reactive.onCleanup(function()
			focusLost:Disconnect()
		end)

		if p.onValueChange then
			Reactive.watch(value, function(new)
				p.onValueChange(new, h)
			end)
		end

		local function stepper(direction: number, order: number, name: string, slot: string)
			-- Blocked while disabled, and at the end it steps towards.
			local function blocked(): boolean
				if disabled() then
					return true
				end
				return if direction > 0 then value() >= max() else value() <= min()
			end
			local function open(): boolean
				return not blocked()
			end
			local icon =
				Icon.new({ app = app, icon = slot, size = NumberField.iconSize, name = name .. "Icon" })
			icon.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Instance.Position = UDim2.fromScale(0.5, 0.5)
			return Element.new("TextButton", {
				Name = name,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = order,
				-- Mouse and touch only: on keyboard and gamepad the field is the stop.
				Selectable = false,
				Interactable = open,
				Tags = {
					"ui-button" :: any,
					"ui-button-variant-outline",
					"ui-button-size-icon",
					"ui-number-field-step",
					["ui-disabled"] = blocked,
				},
				[Element.on("MouseButton1Down")] = function()
					h:_press(direction)
				end :: any,
				[Element.on("MouseButton1Up")] = function()
					h:_release()
				end :: any,
				[Element.on("MouseLeave")] = function()
					h:_release()
				end :: any,
				icon.Instance,
			})
		end
		local minus = stepper(-1, 1, "Minus", "lucy:minus")
		local plus = stepper(1, 3, "Plus", "lucy:plus")
		h.minus, h.plus = minus, plus

		return Element.new("Frame", {
			BackgroundTransparency = 1,
			Size = function()
				return UDim2.new(width.Scale, width.Offset, 0, height())
			end,
			Visible = h:ref("visible"),
			Element.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			minus,
			box,
			plus,
		})
	end,
}

function NumberField.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	-- Where a press, held arrow or typing started, to commit only a real change.
	local holdFrom: number? = nil
	local pressing: {}? = nil

	local function commit(h, from: number)
		local value = h:get("value")
		if value == from then
			return
		end
		h:emit("select", value)
		local onCommit = h.props.onValueCommit
		if onCommit then
			onCommit(value, h)
		end
	end

	function handle.setValue(h, value: number)
		h:set("value", NumberField.snap(value, h:get("min"), h:get("max"), h:get("step")))
	end

	--[[
		Left or right (InputManager.nudge, the buttons): dx is -1 or 1, `count` how
		many times it has fired while held. Up and down are not taken, and nothing
		is while the player is typing in the field.
	]]
	function handle.nudge(h, dx: number, dy: number, count: number?): boolean
		if h.destroyed or h:get("disabled") or dy ~= 0 or dx == 0 then
			return false
		end
		if h.field.Instance:IsFocused() then
			return false
		end
		local value, min, max, step = h:get("value"), h:get("min"), h:get("max"), h:get("step")
		if holdFrom == nil then
			holdFrom = value
		end
		local stride = if step > 0 then step else 1
		if (count or 1) > NumberField.fastAfter then
			local range = max - min
			if range < math.huge and range > 0 then
				stride = math.max(stride, stride * math.floor(range / stride / NumberField.fastParts))
			else
				stride *= NumberField.fastSteps
			end
		end
		h:set("value", NumberField.snap(value + dx * stride, min, max, step))
		return true
	end

	-- The held arrow or button was let go.
	function handle.release(h)
		local from = holdFrom
		holdFrom = nil
		if from ~= nil and not h.destroyed then
			commit(h, from)
		end
	end

	-- A button pressed (direction -1 or 1): one step now, repeating while held.
	function handle._press(h, direction: number)
		if h.destroyed or h:get("disabled") then
			return
		end
		local token = {}
		pressing = token
		h:nudge(direction, 0, 1)
		task.delay(InputManager.repeatDelay, function()
			local count = 1
			while pressing == token and not h.destroyed do
				count += 1
				h:nudge(direction, 0, count)
				task.wait(InputManager.repeatRate)
			end
		end)
	end

	function handle._release(h)
		if pressing == nil then
			return
		end
		pressing = nil
		h:release()
	end

	-- The player left the field or pressed Enter: take the typed number, or put
	-- the value back.
	function handle._commitText(h)
		local typed = h._draft()
		if typed == false or h.destroyed then
			return
		end
		local from = h:get("value")
		local number = tonumber(typed)
		if number ~= nil and number == number and math.abs(number) ~= math.huge then
			h:setValue(number)
		end
		h._draft(false)
		commit(h, from)
	end

	return handle
end

return NumberField
