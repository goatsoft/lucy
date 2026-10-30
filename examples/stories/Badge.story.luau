return {
	group = "Components",
	description = "Small status labels.",
	controls = {
		text = "New",
		variant = { "default", "secondary", "destructive", "outline" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		return {
			Lucy.Badge.new({ text = ctx.controls.text, variant = ctx.controls.variant }),
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space2",
				justify = "center",
				children = {
					Lucy.Badge.new({ text = "New" }),
					Lucy.Badge.new({ text = "Beta", variant = "secondary" }),
					Lucy.Badge.new({ text = "Hot", variant = "destructive" }),
					Lucy.Badge.new({ text = "v0.1", variant = "outline" }),
				},
			}),
		}
	end,
}
