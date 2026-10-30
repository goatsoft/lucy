--!strict
--[[
	Slider: picks a number in a range by dragging, or with the arrows.

		Slider.new({
			value = 50,
			min = 0,
			max = 100,
			step = 1,
			orientation = "horizontal", -- horizontal | vertical
			size = "md",                -- sm | md | lg
			disabled = false,
			visible = true,
			showValue = false,          -- the value beside the track
			format = function(value) return `{value}%` end,
			valueWidth = 40,            -- room for the value when shown (horizontal)
			length = 240,               -- pixels; horizontal fills its parent's width when left out
			onValueChange = function(value, slider) end, -- every step, while dragging too
			onValueCommit = function(value, slider) end, -- when a drag or held arrow ends
			Parent = settings,
		})
		slider:setValue(75)

	Mouse and touch drag the thumb or press anywhere on the track. With focus on
	it, the arrows along its axis change it (left and right, or up and down when
	vertical; up is more) on keyboard and gamepad, faster while held; the other
	arrows move focus as usual (InputManager.nudge). The engine is told not to
	move gamepad selection along that axis.

	State keys: value, min, max, step, orientation, size, disabled, visible.
	Events: "select" with the value, once per drag or held arrow that changed it.
]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Slider = {}

Slider.orientations = { "horizontal", "vertical" }
Slider.sizes = { "sm", "md", "lg" }

-- Thumb and track thickness at default density, in pixels.
Slider.metrics = {
	sm = { thumb = 14, track = 4 },
	md = { thumb = 18, track = 6 },
	lg = { thumb = 22, track = 8 },
}
local DENSITY_SCALE: { [string]: number } = { default = 1, touch = 1.25, tv = 1.5 }

Slider.defaultLength = 160 -- a vertical slider's height when `length` is left out
Slider.valueWidth = 40
Slider.valueHeight = 20 -- room for the value under a vertical slider
-- A held arrow moves one step at a time, then after this many repeats a 25th of
-- the range per repeat.
Slider.fastAfter = 12
Slider.fastParts = 25

local rules: { Component.Rule } = {
	-- The focus ring goes round the thumb (the halo), not the whole row.
	{
		selector = ".ui-slider.ui-focus-visible::UIStroke",
		priority = 101,
		properties = { Transparency = 1 },
	},
	{
		selector = ".ui-slider-track",
		priority = 0,
		properties = { BackgroundColor3 = "$Secondary", BorderSizePixel = 0 },
	},
	{ selector = ".ui-slider-track::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-slider-fill",
		priority = 0,
		properties = { BackgroundColor3 = "$Primary", BorderSizePixel = 0 },
	},
	{ selector = ".ui-slider-fill::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-slider-thumb",
		priority = 0,
		properties = { BackgroundColor3 = "$White", BorderSizePixel = 0 },
	},
	{ selector = ".ui-slider-thumb::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-slider-thumb::UIStroke",
		priority = 0,
		properties = {
			Color = "$Primary",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	-- The thumb's focus ring: the base focus ring's tokens, on a stroke round the
	-- thumb, shown while the slider has the focus ring.
	{
		selector = ".ui-slider-halo",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{ selector = ".ui-slider-halo::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-slider-ring",
		priority = 0,
		properties = {
			Color = "$Ring",
			Thickness = "$FocusRing",
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	{
		selector = ".ui-slider.ui-focus-visible >> .ui-slider-ring",
		priority = 20,
		properties = { Transparency = 0 },
	},
	-- The same ring while the mouse is over it, and while dragging.
	{
		selector = ".ui-slider.ui-slider-hover >> .ui-slider-ring",
		priority = 20,
		properties = { Transparency = 0 },
	},
	{
		selector = ".ui-slider-value",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-slider.ui-disabled >> .ui-slider-track",
		priority = 30,
		properties = { BackgroundTransparency = 0.5 },
	},
	{
		selector = ".ui-slider.ui-disabled >> .ui-slider-fill",
		priority = 30,
		properties = { BackgroundTransparency = 0.5 },
	},
	{
		selector = ".ui-slider.ui-disabled >> .ui-slider-value",
		priority = 30,
		properties = { TextTransparency = 0.5 },
	},
}
Slider.rules = rules

-- `value` clamped to min..max and rounded to the nearest step counted from min.
function Slider.snap(value: number, min: number, max: number, step: number?): number
	if max < min then
		max = min
	end
	local v = math.clamp(value, min, max)
	if step and step > 0 then
		local n = math.floor((v - min) / step + 0.5)
		local top = math.floor((max - min) / step + 1e-9)
		v = min + math.clamp(n, 0, top) * step
		-- Drop float noise (0.1 * 3 is 0.30000000000000004).
		v = tonumber(string.format("%.10g", v)) :: number
	end
	return v
end

-- Where `value` sits between min and max, 0 to 1.
function Slider.fraction(value: number, min: number, max: number): number
	if max <= min then
		return 0
	end
	return math.clamp((value - min) / (max - min), 0, 1)
end

-- The value shown when `format` is left out: whole numbers without a point.
function Slider.format(value: number): string
	if value == math.floor(value) then
		return string.format("%d", value)
	end
	return string.format("%.10g", value)
end

local function check(list: { string }, value: string, what: string)
	if not table.find(list, value) then
		error(`[Lucy] unknown Slider {what} "{value}" (expected {table.concat(list, ", ")})`, 0)
	end
end

-- One tag list per orientation and size pair, shared by every Slider.
local tagLists: { [string]: { [string]: { string } } } = {}
local function variantTags(orientation: string, size: string): { string }
	local bySize = tagLists[orientation]
	if not bySize then
		bySize = {}
		tagLists[orientation] = bySize
	end
	local list = bySize[size]
	if not list then
		list = { "ui-slider-orientation-" .. orientation, "ui-slider-size-" .. size }
		bySize[size] = list
	end
	return list
end

-- An input's position in the same space as AbsolutePosition under `object`'s gui.
local function screenPoint(input: InputObject, object: Instance): Vector2
	local point = Vector2.new(input.Position.X, input.Position.Y)
	local gui = object:FindFirstAncestorWhichIsA("ScreenGui")
	if gui and gui.IgnoreGuiInset then
		point += GuiService:GetGuiInset()
	end
	return point
end

local STOP, ESCAPE = Enum.SelectionBehavior.Stop, Enum.SelectionBehavior.Escape
local TOP_LEFT, BOTTOM_LEFT = Vector2.zero, Vector2.new(0, 1)
local CENTRE = Vector2.new(0.5, 0.5)

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "slider",
	defaults = {
		value = 0,
		min = 0,
		max = 100,
		step = 1,
		orientation = "horizontal",
		size = "md",
		disabled = false,
		visible = true,
	},
	rules = Slider.rules,
	render = function(h)
		-- An unknown orientation or size fails the mount; later writes report like any effect.
		check(Slider.orientations, h:get("orientation"), "orientation")
		check(Slider.sizes, h:get("size"), "size")
		local p: Component.Props = h.props
		local value, min, max = h:ref("value"), h:ref("min"), h:ref("max")
		local orientation, size, disabled = h:ref("orientation"), h:ref("size"), h:ref("disabled")
		local density = Composables.useDensity(h.app)
		local showValue = p.showValue == true
		local format: (number) -> string = p.format or Slider.format
		local valueWidth: number = p.valueWidth or Slider.valueWidth
		local length: number? = p.length

		local function vertical(): boolean
			return orientation() == "vertical"
		end
		local function scaled(px: number): number
			return math.floor(px * (DENSITY_SCALE[density()] or 1) + 0.5)
		end
		local function thumbPx(): number
			return scaled((Slider.metrics[size()] or Slider.metrics.md).thumb)
		end
		local function trackPx(): number
			return scaled((Slider.metrics[size()] or Slider.metrics.md).track)
		end
		local function fraction(): number
			return Slider.fraction(value(), min(), max())
		end
		local function enabled(): boolean
			return not disabled()
		end
		-- Pointer over it (mouse only, set by _pointer) or dragging it.
		local hovered, pressing = Reactive.ref(false), Reactive.ref(false)
		h._hovered, h._pressing = hovered, pressing
		local function hover(): boolean
			return not disabled() and (hovered() or pressing())
		end
		-- The control's thickness across its axis: the thumb with room for the
		-- focus ring, at least a small control's height.
		local function thickness(): number
			return math.max(thumbPx() + 8, Component.metric(h.app, "ControlSm"))
		end

		local fill = Element.new("Frame", {
			Name = "Fill",
			AnchorPoint = function()
				return if vertical() then BOTTOM_LEFT else TOP_LEFT
			end,
			Position = function()
				return if vertical() then UDim2.fromScale(0, 1) else UDim2.fromScale(0, 0)
			end,
			Size = function()
				local f = fraction()
				return if vertical() then UDim2.fromScale(1, f) else UDim2.fromScale(f, 1)
			end,
			Tags = { "ui-slider-fill" },
		})
		local track = Element.new("Frame", {
			Name = "Track",
			ZIndex = 1,
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				local t = trackPx()
				return if vertical() then UDim2.new(0, t, 1, 0) else UDim2.new(1, 0, 0, t)
			end,
			Tags = { "ui-slider-track" },
			fill,
		})
		local function thumbPosition(): UDim2
			local f = fraction()
			return if vertical() then UDim2.fromScale(0.5, 1 - f) else UDim2.fromScale(f, 0.5)
		end
		local thumb = Element.new("Frame", {
			Name = "Thumb",
			AnchorPoint = CENTRE,
			ZIndex = 3,
			Position = thumbPosition,
			Size = function()
				local k = thumbPx()
				return UDim2.fromOffset(k, k)
			end,
			Tags = { "ui-slider-thumb" },
		})
		-- Holds the thumb's focus ring: a clear disc just round the thumb's border,
		-- whose stroke is styled like the base focus ring.
		local theme = h.app.theme
		local ring = Element.new("UIStroke", { Tags = { "ui-slider-ring" } })
		local halo = Element.new("Frame", {
			Name = "Halo",
			AnchorPoint = CENTRE,
			ZIndex = 2,
			Position = thumbPosition,
			Size = function()
				local k = thumbPx() + 2 * theme:resolve("StrokeThin")
				return UDim2.fromOffset(k, k)
			end,
			Tags = { "ui-slider-halo" },
			ring,
		})
		-- The thumb's centre travels the whole track, so the rail is inset by half a
		-- thumb along the axis to keep it inside the control.
		local function inset(): UDim
			return UDim.new(0, math.ceil(thumbPx() / 2))
		end
		local function insetX(): UDim
			return if vertical() then UDim.new() else inset()
		end
		local function insetY(): UDim
			return if vertical() then inset() else UDim.new()
		end
		local rail = Element.new("Frame", {
			Name = "Rail",
			BackgroundTransparency = 1,
			Size = function()
				if not showValue then
					return UDim2.fromScale(1, 1)
				end
				return if vertical()
					then UDim2.new(1, 0, 1, -Slider.valueHeight)
					else UDim2.new(1, -(valueWidth + 8), 1, 0)
			end,
			Element.new("UIPadding", {
				PaddingLeft = insetX,
				PaddingRight = insetX,
				PaddingTop = insetY,
				PaddingBottom = insetY,
			}),
			track,
			halo,
			thumb,
		})
		local valueLabel = Element.new("TextLabel", {
			Name = "Value",
			Visible = showValue,
			Text = function()
				return format(value())
			end,
			AnchorPoint = function()
				return if vertical() then BOTTOM_LEFT else Vector2.new(1, 0)
			end,
			Position = function()
				return if vertical() then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 0)
			end,
			Size = function()
				return if vertical()
					then UDim2.new(1, 0, 0, Slider.valueHeight)
					else UDim2.new(0, valueWidth, 1, 0)
			end,
			TextXAlignment = function()
				return if vertical() then Enum.TextXAlignment.Center else Enum.TextXAlignment.Right
			end,
			Tags = { "ui-slider-value" },
		})
		h.track, h.fill, h.thumb, h.halo, h.ring = track, fill, thumb, halo, ring
		h.rail, h.valueLabel = rail, valueLabel

		-- Side effects: the player's callback, and the engine's drag listeners.
		if p.onValueChange then
			Reactive.watch(value, function(new)
				p.onValueChange(new, h)
			end)
		end
		local dragging: { RBXScriptConnection } = {}
		local function stopListening()
			for _, connection in dragging do
				connection:Disconnect()
			end
			table.clear(dragging)
		end
		Reactive.onCleanup(stopListening)

		local function alongX(): Enum.SelectionBehavior
			return if vertical() then ESCAPE else STOP
		end
		local function alongY(): Enum.SelectionBehavior
			return if vertical() then STOP else ESCAPE
		end

		return Element.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = function()
				local t = thickness()
				if vertical() then
					local wide = if showValue then math.max(t, valueWidth) else t
					return UDim2.fromOffset(wide, length or Slider.defaultLength)
				end
				return if length then UDim2.fromOffset(length, t) else UDim2.new(1, 0, 0, t)
			end,
			Visible = h:ref("visible"),
			Interactable = enabled,
			Selectable = enabled,
			SelectionBehaviorLeft = alongX,
			SelectionBehaviorRight = alongX,
			SelectionBehaviorUp = alongY,
			SelectionBehaviorDown = alongY,
			Tags = {
				"ui-slider" :: any,
				-- Orientation and size in one binding: they rarely change.
				function()
					local o, s = orientation(), size()
					check(Slider.orientations, o, "orientation")
					check(Slider.sizes, s, "size")
					return variantTags(o, s)
				end,
				["ui-disabled"] = disabled,
				["ui-slider-hover"] = hover,
			},
			[Element.on("MouseEnter")] = function()
				h:_pointer(true)
			end :: any,
			[Element.on("MouseLeave")] = function()
				h:_pointer(false)
			end :: any,
			[Element.on("InputBegan")] = function(input: InputObject)
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
					return
				end
				if h.destroyed or h:get("disabled") then
					return
				end
				stopListening()
				local root = h.Instance
				h:pointerDown(screenPoint(input, root))
				table.insert(
					dragging,
					UserInputService.InputChanged:Connect(function(changed: InputObject)
						local moved = if kind == Enum.UserInputType.Touch
							then changed == input
							else changed.UserInputType == Enum.UserInputType.MouseMovement
						if moved then
							h:pointerMove(screenPoint(changed, root))
						end
					end)
				)
				table.insert(
					dragging,
					UserInputService.InputEnded:Connect(function(ended: InputObject)
						local done = if kind == Enum.UserInputType.Touch
							then ended == input
							else ended.UserInputType == Enum.UserInputType.MouseButton1
						if done then
							stopListening()
							h:pointerUp()
						end
					end)
				)
			end,
			rail,
			valueLabel,
		})
	end,
}

function Slider.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	-- Where a gesture started, to commit only when it changed something.
	local dragFrom: number? = nil
	local holdFrom: number? = nil

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

	-- The mouse came over it (true) or left (false). Ignored on other input, so a
	-- tap does not leave a ring behind. Called by the engine's events and specs.
	function handle._pointer(h, on: boolean)
		if on and (h.app.input:mode() ~= "mouse" or h:get("disabled")) then
			on = false
		end
		h._hovered(on)
	end

	-- Writes `value`, snapped to the step and range.
	function handle.setValue(h, value: number)
		h:set("value", Slider.snap(value, h:get("min"), h:get("max"), h:get("step")))
	end

	-- The value under a screen point on the track.
	function handle.valueAt(h, point: Vector2): number
		local track: GuiObject = h.track
		local pos, size = track.AbsolutePosition, track.AbsoluteSize
		local f
		if h:get("orientation") == "vertical" then
			f = if size.Y > 0 then 1 - (point.Y - pos.Y) / size.Y else 0
		else
			f = if size.X > 0 then (point.X - pos.X) / size.X else 0
		end
		local min, max = h:get("min"), h:get("max")
		return Slider.snap(min + math.clamp(f, 0, 1) * (max - min), min, max, h:get("step"))
	end

	-- The drag path, called by the engine's input (and by specs).
	function handle.pointerDown(h, point: Vector2)
		if h.destroyed or h:get("disabled") then
			return
		end
		dragFrom = h:get("value")
		h._pressing(true)
		h:set("value", h:valueAt(point))
	end

	function handle.pointerMove(h, point: Vector2)
		if dragFrom == nil or h.destroyed or h:get("disabled") then
			return
		end
		h:set("value", h:valueAt(point))
	end

	function handle.pointerUp(h)
		local from = dragFrom
		dragFrom = nil
		if not h.destroyed then
			h._pressing(false)
		end
		if from ~= nil and not h.destroyed then
			commit(h, from)
		end
	end

	--[[
		An arrow along the slider's axis (InputManager.nudge): dx and dy are -1, 0
		or 1 in screen terms (dy = -1 is up). `count` is how many times the arrow
		has fired while held. Returns whether it was taken.
	]]
	function handle.nudge(h, dx: number, dy: number, count: number?): boolean
		if h.destroyed or h:get("disabled") then
			return false
		end
		local direction
		if h:get("orientation") == "vertical" then
			if dx ~= 0 or dy == 0 then
				return false
			end
			direction = -dy
		else
			if dy ~= 0 or dx == 0 then
				return false
			end
			direction = dx
		end
		local value, min, max, step = h:get("value"), h:get("min"), h:get("max"), h:get("step")
		if holdFrom == nil then
			holdFrom = value
		end
		local stride = if step > 0 then step else (max - min) / 100
		if (count or 1) > Slider.fastAfter then
			stride = math.max(stride, stride * math.floor((max - min) / stride / Slider.fastParts))
		end
		h:set("value", Slider.snap(value + direction * stride, min, max, step))
		return true
	end

	-- The held arrow was let go.
	function handle.release(h)
		local from = holdFrom
		holdFrom = nil
		if from ~= nil and not h.destroyed then
			commit(h, from)
		end
	end

	return handle
end

return Slider
