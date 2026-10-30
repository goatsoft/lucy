return {
	group = "Components",
	description = "Drag, or focus it and use the arrows along its axis. The value and the last committed value show below.",
	width = 360,
	controls = {
		orientation = { "horizontal", "vertical" },
		size = { "md", "sm", "lg" },
		showValue = true,
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local volume = Lucy.ref(80)
		local committed = Lucy.ref(80)

		return Lucy.Stack.new({
			gap = "Space4",
			children = {
				Lucy.Slider.new({
					value = volume,
					orientation = c.orientation,
					size = c.size,
					disabled = c.disabled,
					showValue = c.showValue(),
					format = function(value)
						return `{value}%`
					end,
					onValueCommit = function(value)
						committed(value)
					end,
				}),
				Lucy.Slider.new({
					value = 0.5,
					min = 0,
					max = 1,
					step = 0.05,
					size = c.size,
					disabled = c.disabled,
				}),
				Lucy.Text.new({
					text = function()
						return `Volume {volume()}, committed {committed()}`
					end,
					variant = "muted",
				}),
			},
		})
	end,
}
