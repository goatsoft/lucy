--!strict
--[[
	Switch

		Switch.new({
			label = "Music",
			children = { ... },   -- optional: after the label in its slot (Slot: strings, handles,
			                      -- instances, builders); Foreground, faded when disabled
			checked = true,
			disabled = false,
			size = "md",          -- sm | md | lg | xl: the track, the label and the row's height
			onCheckedChange = function(checked, switch) end,
		})
		switch:toggle()

	The row is as tall as a control of the same size (Component.controlTokens), so a switch
	lines up with a Button or Toggle of its size; the label takes that size's text. Track and
	thumb grow with size and with density (md: 36x20 desktop, 44x24 touch, 52x28 console);
	the whole row is the hit area. State keys: checked, label, disabled, size, visible.
	Declarative (ADR 0018): the instances bind to state; the only side effects are
	the thumb slide and onCheckedChange.
]]

local TweenService = game:GetService("TweenService")

local Component = require(script.Parent.Parent.Core.Component)
local Slot = require(script.Parent.Slot)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Switch = {}

Switch.sizes = Component.controlSizes

-- The track at each size, for each density (the thumb is its height less 4)
Switch.tracks = {
	sm = { default = Vector2.new(30, 16), touch = Vector2.new(36, 20), tv = Vector2.new(44, 24) },
	md = { default = Vector2.new(36, 20), touch = Vector2.new(44, 24), tv = Vector2.new(52, 28) },
	lg = { default = Vector2.new(44, 24), touch = Vector2.new(52, 28), tv = Vector2.new(60, 32) },
	xl = { default = Vector2.new(52, 28), touch = Vector2.new(60, 32), tv = Vector2.new(68, 36) },
} :: { [string]: { [string]: Vector2 } }

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
	{ selector = ".ui-switch-label.ui-switch-size-sm", priority = 5, properties = { TextSize = "$TextXs" } },
	{
		selector = ".ui-switch-label.ui-switch-size-lg",
		priority = 5,
		properties = { TextSize = "$TextBase" },
	},
	{ selector = ".ui-switch-label.ui-switch-size-xl", priority = 5, properties = { TextSize = "$TextLg" } },
	{ selector = ".ui-switch.ui-disabled", priority = 30, properties = { BackgroundTransparency = 0.5 } },
	{ selector = ".ui-switch-label.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
}
Switch.rules = rules
-- What sits beside the switch takes its label's look (ADR 0042)
for _, rule in Slot.beside(".ui-switch-root") do
	table.insert(Switch.rules, rule)
end

local SLIDE = TweenInfo.new(0.15, Enum.EasingStyle.Quad)

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "switch",
	defaults = { checked = false, label = "", disabled = false, size = "md", visible = true },
	rules = Switch.rules,
	render = function(h)
		local p: Component.Props = h.props
		local checked, disabled = h:ref("checked"), h:ref("disabled")
		local label, visible, sizeName = h:ref("label"), h:ref("visible"), h:ref("size")
		Component.checkControlSize(h:get("size"), "Switch")
		local density = Composables.useDensity(h.app)
		-- Trivial derivations are plain functions: a computed only pays off when
		-- the work is expensive or many readers share it.
		local function tracks(): { [string]: Vector2 }
			local name = sizeName()
			Component.checkControlSize(name, "Switch")
			return Switch.tracks[name]
		end
		local function size(): Vector2
			local list = tracks()
			return list[density()] or list.default
		end
		local function sizeTag(): string
			return `ui-switch-size-{sizeName()}`
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
				local tags = { "ui-switch-label", sizeTag() }
				if disabled() then
					table.insert(tags, "ui-disabled")
				end
				return tags
			end,
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
			-- With reduced motion the thumb jumps (Core/Preferences).
			if h.Instance and h.Instance.Parent and not Preferences.reducedMotion() then
				slides[on]:Play()
			else
				slides[not on]:Cancel()
				thumb.Position = positions[on]
			end
			if p.onCheckedChange then
				p.onCheckedChange(value, h)
			end
		end)

		local root = Element.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = function()
				-- As tall as a control of its size, so it lines up with them in a row or a form
				local height = Component.controlTokens[sizeName()].height
				return UDim2.fromOffset(0, math.max(Component.metric(h.app, height), size().Y))
			end,
			Visible = visible,
			Interactable = enabled,
			Selectable = enabled,
			Tags = { "ui-switch-root" :: any, "ui-ring-host", ["ui-disabled"] = disabled },
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
		Slot.fill(root, p.children, { app = h.app, startOrder = 2 })
		return root
	end,
}

function Switch.new(props: { [string]: any }?)
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

return Switch
