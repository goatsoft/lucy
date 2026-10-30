return {
	group = "Components",
	description = "A turning ring while something loads. The top spinner follows the controls.",
	width = 360,
	controls = {
		size = { options = { "sm", "md", "lg" }, default = "md" },
		variant = { "default", "muted", "primary" },
		visible = true,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local row = {}
		for _, size in { "sm", "md", "lg" } do
			table.insert(row, Lucy.Spinner.new({ size = size, variant = "muted" }))
		end
		return {
			Lucy.Stack.new({
				gap = "Space6",
				align = "center",
				children = {
					Lucy.Spinner.new({ size = c.size, variant = c.variant, visible = c.visible }),
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space4",
						align = "center",
						children = row,
					}),
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space2",
						align = "center",
						children = {
							Lucy.Spinner.new({ size = "sm", variant = "muted" }),
							Lucy.Text.new({ text = "Finding a server", variant = "muted", autoWidth = true }),
						},
					}),
				},
			}),
		}
	end,
}
