return {
	group = "Components",
	description = "Key caps for the player's input. Switch input to see them change; on touch only the touch label shows.",
	width = 420,
	controls = {
		input = { "keyboard", "gamepad", "touch" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		-- Preview only: pretend the player switched input.
		Lucy.watch(ctx.controls.input, function(mode)
			ctx.app.input:setMode(mode)
		end, { immediate = true })
		local function row(text, keys)
			return Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space2",
				align = "center",
				children = {
					Lucy.Kbd.new(keys),
					Lucy.Text.new({ text = text, variant = "muted", autoWidth = true }),
				},
			})
		end
		return {
			Lucy.Stack.new({
				gap = "Space3",
				children = {
					row("Join the competition", { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.DPadUp }),
					row("Close", { keyboard = Enum.KeyCode.Escape, gamepad = Enum.KeyCode.ButtonB }),
					row("Next tab", { keyboard = Enum.KeyCode.Tab, gamepad = Enum.KeyCode.ButtonR1 }),
					row(
						"Dance",
						{ keyboard = Enum.KeyCode.Space, gamepad = Enum.KeyCode.ButtonA, touch = "Tap" }
					),
					Lucy.Button.new({
						text = "Join",
						hint = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.DPadUp },
					}),
				},
			}),
		}
	end,
}
