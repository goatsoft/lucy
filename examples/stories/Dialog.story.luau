return {
	group = "Components",
	description = "Open is two-way: closing the dialog clears the control.",
	controls = {
		open = true,
		title = "Leave match?",
		description = "You will drop the cash you are carrying.",
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local dialog = Lucy.Dialog.new({
			open = c.open,
			title = c.title,
			description = c.description,
			actions = {
				{ text = "Stay", variant = "outline" },
				{
					text = "Leave",
					variant = "destructive",
					onClick = function()
						ctx.app.toast("Left the match")
					end,
				},
			},
		})
		return {
			Lucy.Button.new({
				text = "Open dialog",
				variant = "outline",
				onClick = function()
					dialog:open()
				end,
			}),
		}
	end,
}
