--!strict
--[[
	Skeleton: a pulsing placeholder while content loads.

		Skeleton.new({ size = UDim2.fromOffset(250, 16) })
		Skeleton.new({ size = UDim2.fromOffset(48, 48), circle = true })

	State keys: visible. The pulse stops while hidden and on destroy.
]]

local TweenService = game:GetService("TweenService")

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Skeleton = {}

local rules: { Component.Rule } = {
	{
		selector = ".ui-skeleton",
		priority = 0,
		properties = { BackgroundColor3 = "$Muted", BorderSizePixel = 0 },
	},
	{ selector = ".ui-skeleton::UICorner", priority = 0, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-skeleton-circle::UICorner",
		priority = 10,
		properties = { CornerRadius = "$RadiusFull" },
	},
}
Skeleton.rules = rules

Skeleton.pulse = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

function Skeleton.new(props: { [string]: any }?)
	local p: Component.Props = props or {}
	return Component.mount({
		kind = "skeleton",
		props = p,
		defaults = { visible = true },
		rules = Skeleton.rules,
		render = function(h)
			local visible = h:ref("visible")
			local frame = Element.new("Frame", {
				Size = p.size or UDim2.new(1, 0, 0, 16),
				Visible = visible,
				Tags = if p.circle then { "ui-skeleton", "ui-skeleton-circle" } else { "ui-skeleton" },
			})
			-- Side effect: the pulse plays while visible.
			local pulse = TweenService:Create(frame, Skeleton.pulse, { BackgroundTransparency = 0.5 })
			Reactive.watchEffect(function()
				local on = visible() == true
				if on then
					pulse:Play()
				else
					pulse:Cancel()
				end
				h.pulsing = on
			end)
			Reactive.onCleanup(function()
				pulse:Cancel()
			end)
			return frame
		end,
	})
end

return Skeleton
