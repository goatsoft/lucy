return {
	group = "Components",
	description = "Value is clamped to 0..max. Animate it with a spring for smooth bars. With steps, a rail of numbered markers.",
	controls = {
		value = { min = 0, max = 100, step = 5, default = 40 },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local value = ctx.controls.value
		local smooth = Lucy.spring(value, 4)
		return {
			Lucy.Progress.new({ value = value }),
			Lucy.Progress.new({ value = smooth }),
			Lucy.Text.new({
				variant = "muted",
				align = "center",
				text = function()
					return `{value()}% (top: instant, bottom: spring)`
				end,
			}),
			-- Stepped: the same value as ten tiers
			Lucy.Progress.new({
				steps = 10,
				stepSize = 32,
				height = 10,
				value = function()
					return smooth() / 10
				end,
			}),
			Lucy.Text.new({
				variant = "muted",
				align = "center",
				text = function()
					return `steps = 10: tier {value() // 10}, {value() % 10 * 10}% of the way to the next`
				end,
			}),
		}
	end,
}
