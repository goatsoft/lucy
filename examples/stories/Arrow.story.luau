return {
	group = "Components",
	description = "Lucy.Arrow pointing at a button. Pick its shape, motion and direction; REPLAY grows it in again.",
	controls = {
		variant = { "arrow", "chevron", "triangle" },
		motion = { "bounce", "pulse", "none" },
		direction = { "down", "up", "left", "right" },
		size = { "md", "sm", "lg" },
		color = { "Ring", "Primary", "Destructive", "Success" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls

		local arrow
		local target = Lucy.Button.new({
			text = "Play",
			onClick = function()
				arrow:replay()
			end,
		})
		arrow = Lucy.Arrow.new({
			variant = c.variant,
			motion = c.motion,
			direction = c.direction,
			size = c.size,
			color = c.color,
		})

		-- The arrow stands off the button on the side it points from.
		local holder = Lucy.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(320, 240),
			target.Instance,
			arrow.Instance,
		})
		target.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
		target.Instance.Position = UDim2.fromScale(0.5, 0.5)
		local GAP = 36
		Lucy.watchEffect(function()
			local way = c.direction()
			local spot = ({
				down = UDim2.new(0.5, 0, 0.5, -GAP),
				up = UDim2.new(0.5, 0, 0.5, GAP),
				left = UDim2.new(0.5, GAP + 30, 0.5, 0),
				right = UDim2.new(0.5, -GAP - 30, 0.5, 0),
			})[way]
			arrow.Instance.Position = spot
		end)

		return Lucy.Stack.new({
			direction = "vertical",
			gap = "Space4",
			align = "center",
			children = {
				holder,
				Lucy.Button.new({
					text = "Replay",
					variant = "secondary",
					onClick = function()
						arrow:replay()
					end,
				}),
			},
		})
	end,
}
