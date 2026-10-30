return {
	group = "Components",
	description = "Two-way: flipping the switch updates the checked control.",
	controls = {
		label = "Show hints",
		checked = true,
		disabled = false,
	},
	render = function(ctx)
		local c = ctx.controls
		return ctx.Lucy.Switch.new({ label = c.label, checked = c.checked, disabled = c.disabled })
	end,
}
