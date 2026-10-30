--!strict
--[[
	Switch

		Switch.new({
			label = "Music",
			checked = true,
			disabled = false,
			onCheckedChange = function(checked, switch) end,
		})
		switch:toggle()

	Track and thumb grow with density (36x20 desktop, 44x24 touch, 52x28 console);
	the whole row is the hit area. State keys: checked, label, disabled, visible.
	Declarative (ADR 0018): the instances bind to state; the only side effects are
	the thumb slide and onCheckedChange.
]]

local TweenService = game:GetService("TweenService")

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Switch = {}

local TRACK = {
	default = Vector2.new(36, 20),
	touch = Vector2.new(44, 24),
	tv = Vector2.new(52, 28),
}

local rules: { Component.Rule } = {
	{
		selector = ".ui-switch",
		priority = 0,
		properties = { BackgroundColor3 = "$Input", BorderSizePixel = 0 },
	},
	{ selector = ".ui-switch::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-switch.ui-checked",
		priority = 10,
		properties = { BackgroundColor3 = "$Primary" },
		transitions = { BackgroundColor3 = TweenInfo.new(0.15) },
	},
	{
		selector = ".ui-switch-thumb",
		priority = 0,
		properties = { BackgroundColor3 = "$Background", BorderSizePixel = 0 },
	},
	{ selector = ".ui-switch-thumb::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-switch-label",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-switch.ui-disabled", priority = 30, properties = { BackgroundTransparency = 0.5 } },
	{ selector = ".ui-switch-label.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
}
Switch.rules = rules

local SLIDE = TweenInfo.new(0.15, Enum.EasingStyle.Quad)

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "switch",
	defaults = { checked = false, label = "", disabled = false, visible = true },
	rules = Switch.rules,
	render = function(h)
		local p: Component.Props = h.props
		local checked, disabled = h:ref("checked"), h:ref("disabled")
		local label, visible = h:ref("label"), h:ref("visible")
		local density = Composables.useDensity(h.app)
		-- Trivial derivations are plain functions: a computed only pays off when
		-- the work is expensive or many readers share it.
		local function size(): Vector2
			return TRACK[density()] or TRACK.default
		end
		local function knob(): number
			return size().Y - 4
		end
		local function enabled(): boolean
			return not disabled()
		end

		local thumb = Element.new("Frame", {
			Name = "Thumb",
			AnchorPoint = Vector2.new(0, 0.5),
			Size = function()
				return UDim2.fromOffset(knob(), knob())
			end,
			Tags = { "ui-switch-thumb" },
		})
		local track = Element.new("Frame", {
			Name = "Track",
			LayoutOrder = 1,
			Size = function()
				return UDim2.fromOffset(size().X, size().Y)
			end,
			Tags = { "ui-switch", ["ui-checked"] = checked, ["ui-disabled"] = disabled },
			thumb,
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
			Tags = { "ui-switch-label", ["ui-disabled"] = disabled },
		})
		h.track, h.thumb, h.label = track, thumb, text

		-- Side effects. The thumb slides with one of two prebuilt tweens (Play on one
		-- overrides the other), rebuilt when the density changes the track.
		local slides: { [boolean]: Tween } = {}
		local positions: { [boolean]: UDim2 } = {}
		Reactive.watchEffect(function()
			local width, side = size().X, knob()
			positions = { [true] = UDim2.new(0, width - side - 2, 0.5, 0), [false] = UDim2.new(0, 2, 0.5, 0) }
			for _, on in { true, false } do
				if slides[on] then
					slides[on]:Cancel()
				end
				slides[on] = TweenService:Create(thumb, SLIDE, { Position = positions[on] })
			end
			thumb.Position = positions[Reactive.peek(checked) == true]
		end)
		Reactive.watch(checked, function(value)
			local on = value == true
			if h.Instance and h.Instance.Parent then
				slides[on]:Play()
			else
				slides[not on]:Cancel()
				thumb.Position = positions[on]
			end
			if p.onCheckedChange then
				p.onCheckedChange(value, h)
			end
		end)

		return Element.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = function()
				return UDim2.fromOffset(0, math.max(Component.metric(h.app, "ControlSm"), size().Y))
			end,
			Visible = visible,
			Interactable = enabled,
			Selectable = enabled,
			Tags = { "ui-switch-root" },
			[Element.on("Activated")] = function()
				h:toggle()
			end,
			Component.list({ -- static: no bindings, so a plain instance
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			}) :: any,
			track,
			text,
		})
	end,
}

function Switch.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	function handle.toggle(h)
		if h:get("disabled") then
			return
		end
		h:set("checked", not h:get("checked"))
	end
	return handle
end

return Switch
