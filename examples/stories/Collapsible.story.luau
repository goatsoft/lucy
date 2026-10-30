return {
	group = "Components",
	description = "Sections that open and close. Click a header, or press A or Enter on it.",
	width = 420,
	controls = {
		variant = { "default", "details" },
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		return {
			Lucy.Stack.new({
				gap = "Space2",
				children = {
					Lucy.Collapsible.new({
						text = "Audio",
						open = true,
						variant = c.variant,
						disabled = c.disabled,
						content = function()
							return Lucy.Stack.new({
								gap = "Space2",
								children = {
									Lucy.Switch.new({ label = "Music", checked = true }),
									Lucy.Switch.new({ label = "Footsteps" }),
								},
							})
						end,
					}),
					Lucy.Collapsible.new({
						text = "Show the rules",
						variant = c.variant,
						disabled = c.disabled,
						content = function()
							return Lucy.Text.new({
								text = "Copy the moves on screen. Each one you hit in time scores a point.",
								variant = "muted",
							})
						end,
					}),
				},
			}),
		}
	end,
}
