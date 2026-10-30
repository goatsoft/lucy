return {
	group = "Components",
	description = "Cards that hold anything. Click one to pick it.",
	width = 520,
	controls = {
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local picked = Lucy.ref("House")
		local cards = {}
		for _, genre in { "House", "Techno", "Hip hop" } do
			table.insert(
				cards,
				Lucy.Pressable.new({
					size = UDim2.fromOffset(140, 96),
					padding = "Space4",
					selected = function()
						return picked() == genre
					end,
					disabled = ctx.controls.disabled,
					onClick = function()
						picked(genre)
					end,
					children = {
						Lucy.Stack.new({
							gap = "Space1",
							children = {
								Lucy.Text.new({ text = genre, variant = "large" }),
								Lucy.Text.new({ text = "Tonight's vote", variant = "muted" }),
							},
						}),
					},
				})
			)
		end
		return {
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space2",
				wrap = true,
				justify = "center",
				size = UDim2.fromScale(1, 0),
				automaticSize = Enum.AutomaticSize.Y,
				children = cards,
			}),
		}
	end,
}
