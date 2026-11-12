return {
	group = "Components",
	description = "Small status labels.",
	controls = {
		text = "New",
		variant = { "default", "secondary", "destructive", "outline", "overlay" },
		shape = { "rounded", "square" },
		size = { "sm", "md", "lg", "xl" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		return {
			Lucy.Badge.new({
				text = ctx.controls.text,
				variant = ctx.controls.variant,
				shape = ctx.controls.shape,
				size = ctx.controls.size,
			}),
			-- Each size, its words as a Button's at that size
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space2",
				justify = "center",
				align = "center",
				children = {
					Lucy.Badge.new({ text = "SM", variant = "outline", size = "sm" }),
					Lucy.Badge.new({ text = "MD", variant = "outline", size = "md" }),
					Lucy.Badge.new({ text = "LG", variant = "outline", size = "lg" }),
					Lucy.Badge.new({ text = "XL", variant = "outline", size = "xl" }),
				},
			}),
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
			-- The slot: an icon alone, an icon and words, words and anything after them
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space2",
				justify = "center",
				children = {
					Lucy.Badge.new({ icon = "lucide-extended:music-filled", variant = ctx.controls.variant }),
					Lucy.Badge.new({
						icon = "lucide-extended:users-filled",
						text = "12",
						variant = ctx.controls.variant,
					}),
					Lucy.Badge.new({
						text = "LV 12",
						variant = ctx.controls.variant,
						children = { Lucy.Icon.new({ icon = "lucide-extended:star-filled", size = 14 }) },
					}),
				},
			}),
		}
	end,
}
