--!strict
--[[
	Spinner: a turning ring that shows something is loading.

		Spinner.new({
			size = "md",          -- sm | md | lg
			variant = "default",  -- default | muted | primary
			visible = true,
			Parent = frame,
		})

	State keys: size, variant, visible. It turns only while visible and stops on
	destroy. With reduced motion (Core/Preferences) the ring stays still and
	pulses instead. handle.stroke is the ring (a UIStroke with a fading UIGradient);
	handle.spinning and handle.pulsing say which it is doing.
]]

local TweenService = game:GetService("TweenService")

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Spinner = {}

Spinner.variants = { "default", "muted", "primary" }
Spinner.sizes = { sm = 16, md = 24, lg = 32 }
-- One turn per 0.8 s, at an even speed, forever.
Spinner.turn = TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
-- With reduced motion: the ring fades to 60% and back, forever.
Spinner.pulse = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- The ring fades out along its length, so it reads as an arc that chases its tail.
local FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 1),
	NumberSequenceKeypoint.new(1, 0),
})

Spinner.rules = {
	{
		selector = ".ui-spinner",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{ selector = ".ui-spinner::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-spinner-ring",
		priority = 0,
		properties = { Color = "$Foreground", Thickness = "$StrokeThick" },
	},
	{ selector = ".ui-spinner-ring-muted", priority = 10, properties = { Color = "$MutedForeground" } },
	{ selector = ".ui-spinner-ring-primary", priority = 10, properties = { Color = "$Primary" } },
	{ selector = ".ui-spinner-ring-sm", priority = 10, properties = { Thickness = 1.5 } },
	{ selector = ".ui-spinner-ring-lg", priority = 10, properties = { Thickness = 3 } },
} :: { Component.Rule }

local function checkVariant(variant: string)
	if not table.find(Spinner.variants, variant) then
		error(
			`[Lucy] unknown Spinner variant "{variant}" (expected {table.concat(Spinner.variants, ", ")})`,
			0
		)
	end
end
local function checkSize(size: string)
	if Spinner.sizes[size] == nil then
		error(`[Lucy] unknown Spinner size "{size}" (expected sm, md or lg)`, 0)
	end
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "spinner",
	defaults = { size = "md", variant = "default", visible = true },
	rules = Spinner.rules,
	render = function(h)
		checkVariant(h:get("variant"))
		checkSize(h:get("size"))
		local size, variant, visible = h:ref("size"), h:ref("variant"), h:ref("visible")

		local stroke = Element.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Tags = {
				"ui-spinner-ring" :: any,
				function()
					local v = variant()
					checkVariant(v)
					return "ui-spinner-ring-" .. v
				end,
				function()
					return "ui-spinner-ring-" .. size()
				end,
			},
			Element.new("UIGradient", { Transparency = FADE }),
		})
		h.stroke = stroke

		local frame = Element.new("Frame", {
			Size = function()
				local s = size()
				checkSize(s)
				local px = Spinner.sizes[s]
				return UDim2.fromOffset(px, px)
			end,
			Visible = visible,
			Tags = {
				"ui-spinner" :: any,
				function()
					return "ui-spinner-size-" .. size()
				end,
			},
			stroke,
		})

		-- Side effect: the turn (or the pulse, with reduced motion) plays while visible.
		local spin = TweenService:Create(frame, Spinner.turn, { Rotation = 360 })
		local pulse = TweenService:Create(stroke, Spinner.pulse, { Transparency = 0.6 })
		Reactive.watchEffect(function()
			local on = visible() == true
			local still = Preferences.reducedMotion()
			spin:Cancel()
			pulse:Cancel()
			frame.Rotation = 0
			stroke.Transparency = 0
			if on and still then
				pulse:Play()
			elseif on then
				spin:Play()
			end
			h.spinning = on and not still
			h.pulsing = on and still
		end)
		Reactive.onCleanup(function()
			spin:Cancel()
			pulse:Cancel()
			h.spinning = false
			h.pulsing = false
		end)
		return frame
	end,
}

function Spinner.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Spinner
