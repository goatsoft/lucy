return {
	group = "Components",
	description = "Typing writes the value control; the line below echoes it.",
	controls = {
		placeholder = "Display name",
		value = "",
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		return {
			Lucy.Input.new({ placeholder = c.placeholder, value = c.value, disabled = c.disabled }),
			Lucy.Text.new({
				variant = "muted",
				text = function()
					return if c.value() == "" then "Nothing typed yet" else `Hello, {c.value()}`
				end,
			}),
		}
	end,
}
