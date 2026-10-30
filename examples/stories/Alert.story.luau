return {
	group = "Components",
	description = "Messages that stay on screen. The top alert follows the controls.",
	width = 480,
	controls = {
		variant = { "default", "destructive", "success", "warning", "info" },
		title = "Server restarting in 5 minutes",
		description = "Your progress is saved. You will join a new server.",
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		return {
			Lucy.Stack.new({
				gap = "Space3",
				children = {
					Lucy.Alert.new({ title = c.title, description = c.description, variant = c.variant }),
					Lucy.Alert.new({
						variant = "destructive",
						title = "Purchase failed",
						description = "You were not charged. Try again in a moment.",
						children = {
							Lucy.Button.new({ text = "Try again", size = "sm", variant = "outline" }),
						},
					}),
					Lucy.Alert.new({
						variant = "success",
						title = "Move unlocked",
						description = "Moonwalk is in your dances.",
					}),
					Lucy.Alert.new({ variant = "info", description = "Competitions start every 10 minutes." }),
				},
			}),
		}
	end,
}
