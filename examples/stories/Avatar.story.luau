return {
	group = "Components",
	description = "Headshots for players and monograms for bots, in three sizes, round or square.",
	width = 420,
	controls = {
		size = { options = { "sm", "md", "lg" }, default = "lg" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local people = {
			{ 156, "builderman" },
			{ 1, "Roblox" },
			{ -1, "DJ God" },
			{ -2, "Robo Dancer" },
			{ 0, "" },
		}
		local row = {}
		for _, person in people do
			table.insert(row, Lucy.Avatar.new({ userId = person[1], name = person[2], size = c.size }))
		end
		local sizes = {}
		for _, size in { "sm", "md", "lg" } do
			table.insert(sizes, Lucy.Avatar.new({ userId = 156, name = "builderman", size = size }))
		end
		table.insert(
			sizes,
			Lucy.Avatar.new({ userId = 156, name = "builderman", size = "lg", square = true })
		)
		return {
			Lucy.Stack.new({
				gap = "Space4",
				align = "center",
				children = {
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space2",
						align = "center",
						children = row,
					}),
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space2",
						align = "center",
						children = sizes,
					}),
				},
			}),
		}
	end,
}
