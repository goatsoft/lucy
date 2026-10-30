--!strict
--[[
	Skeleton: a pulsing placeholder while content loads.

		Skeleton.new({ size = UDim2.fromOffset(250, 16) })
		Skeleton.new({ size = UDim2.fromOffset(48, 48), circle = true })

	State keys: visible. The pulse stops while hidden and on destroy.
]]

local TweenService = game:GetService("TweenService")

local Component = require(script.Parent.Parent.Core.Component)

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
	local tween: Tween? = nil
	return Component.mount({
		kind = "skeleton",
		props = p,
		defaults = { visible = true },
		rules = Skeleton.rules,
		render = function(h)
			local frame = Component.create("Frame", {
				Size = p.size or UDim2.new(1, 0, 0, 16),
				Tags = if p.circle then { "ui-skeleton", "ui-skeleton-circle" } else { "ui-skeleton" },
			})
			h.maid:give(function()
				if tween then
					tween:Cancel()
				end
			end)
			return frame
		end,
		update = function(h, state)
			h.Instance.Visible = state.visible
			if state.visible and not tween then
				local pulse =
					TweenService:Create(h.Instance, Skeleton.pulse, { BackgroundTransparency = 0.5 })
				pulse:Play()
				tween = pulse
			elseif not state.visible and tween then
				tween:Cancel()
				tween = nil
			end
			h.pulsing = tween ~= nil
		end,
	})
end

return Skeleton
