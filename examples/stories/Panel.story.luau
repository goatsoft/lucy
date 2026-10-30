return {
	group = "Components",
	description = "A card with header, content and footer.",
	width = 420,
	controls = {
		title = "Loadout",
		description = "Pick what you take into the round.",
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		return Lucy.Panel.new({
			title = c.title,
			description = c.description,
			children = {
				Lucy.Input.new({ placeholder = "Loadout name" }),
				Lucy.Checkbox.new({ label = "Use as default" }),
			},
			footer = {
				Lucy.Button.new({ text = "Cancel", variant = "outline" }),
				Lucy.Button.new({
					text = "Save",
					onClick = function()
						ctx.app.toast.success("Saved")
					end,
				}),
			},
		})
	end,
}
