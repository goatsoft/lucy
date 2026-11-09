return {
	group = "Components",
	description = "Attribution badges displaying Built with Lucy with Lucy's mascot head.",
	controls = {
		label = "Built with",
		brand = "Lucy",
		variant = { "default", "light", "outline", "secondary", "brand" },
		size = { "md", "sm", "lg" },
		shape = { "rounded", "square" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy

		return {
			-- Interactive controlled badge
			Lucy.Attribution.new({
				label = ctx.controls.label,
				brand = ctx.controls.brand,
				variant = ctx.controls.variant,
				size = ctx.controls.size,
				shape = ctx.controls.shape,
			}),

			-- All variants showcase
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space3",
				justify = "center",
				children = {
					Lucy.Attribution.new({ variant = "default" }),
					Lucy.Attribution.new({ variant = "light" }),
					Lucy.Attribution.new({ variant = "outline" }),
					Lucy.Attribution.new({ variant = "secondary" }),
					Lucy.Attribution.new({ variant = "brand" }),
				},
			}),

			-- Sizes showcase
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space3",
				justify = "center",
				children = {
					Lucy.Attribution.new({ size = "sm", label = "Small" }),
					Lucy.Attribution.new({ size = "md", label = "Normal" }),
					Lucy.Attribution.new({ size = "lg", label = "Large" }),
				},
			}),
		}
	end,
}
