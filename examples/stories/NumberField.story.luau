return {
	group = "Components",
	description = "Press or hold the buttons, type a number and leave the field, or focus it and use left and right.",
	width = 320,
	controls = {
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local players = Lucy.ref(4)
		local committed = Lucy.ref(4)

		return Lucy.Stack.new({
			gap = "Space4",
			children = {
				Lucy.NumberField.new({
					value = players,
					min = 1,
					max = 16,
					disabled = c.disabled,
					onValueCommit = function(value)
						committed(value)
					end,
				}),
				Lucy.NumberField.new({
					value = 1.5,
					min = 0,
					max = 5,
					step = 0.25,
					width = UDim.new(0, 200),
					disabled = c.disabled,
					format = function(value)
						return string.format("%.2fx", value)
					end,
				}),
				Lucy.Text.new({
					text = function()
						return `Players {players()}, committed {committed()}`
					end,
					variant = "muted",
				}),
			},
		})
	end,
}
