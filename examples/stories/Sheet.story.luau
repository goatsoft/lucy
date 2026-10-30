return {
	group = "Components",
	description = "A side panel; a bottom drawer on touch. Switch input, then open it again to see the other shape.",
	controls = {
		open = true,
		input = { "mouse", "touch", "gamepad" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		-- Preview only: pretend the player switched input.
		Lucy.watch(ctx.controls.input, function(mode)
			ctx.app.input:setMode(mode)
		end, { immediate = true })

		local rows = {}
		for index, name in
			{ "Music", "Sound effects", "Camera shake", "Show hints", "Reduce motion", "Chat bubbles" }
		do
			table.insert(
				rows,
				Lucy.Switch.new({ label = name, checked = index % 2 == 1, layoutOrder = index })
			)
		end

		local sheet = Lucy.Sheet.new({
			open = ctx.controls.open,
			title = "Settings",
			description = "Saved to your profile.",
			children = {
				Lucy.Stack.new({ gap = "Space4", children = rows }),
			},
			actions = {
				{ text = "Reset", variant = "outline" },
				{
					text = "Done",
					onClick = function()
						ctx.app.toast("Settings saved")
					end,
				},
			},
		})
		return {
			Lucy.Button.new({
				text = "Open sheet",
				variant = "outline",
				onClick = function()
					sheet:open()
				end,
			}),
		}
	end,
}
