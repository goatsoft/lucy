return {
	group = "Components",
	description = "Two-way: ticking the box updates the checked control.",
	controls = {
		label = "Mute music",
		checked = false,
		disabled = false,
	},
	render = function(ctx)
		local c = ctx.controls
		return ctx.Lucy.Checkbox.new({ label = c.label, checked = c.checked, disabled = c.disabled })
	end,
}
