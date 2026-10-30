return {
	group = "Components",
	description = "Cards in rows. Two columns on a gamepad or phone, four otherwise.",
	width = 560,
	render = function(ctx)
		local Lucy = ctx.Lucy
		local names = { "House", "Techno", "Hip hop", "Disco", "Funk", "Jazz", "Pop" }
		local cards = {}
		for i = 1, 7 do
			table.insert(
				cards,
				Lucy.Pressable.new({
					size = UDim2.fromScale(1, 1),
					padding = "Space3",
					children = {
						Lucy.Stack.new({
							gap = "Space1",
							children = {
								Lucy.Text.new({ text = names[i], variant = "large" }),
								Lucy.Text.new({ text = `{i * 120} coins`, variant = "muted" }),
							},
						}),
					},
				})
			)
		end
		return {
			Lucy.Grid.new({
				columns = { gamepad = 2, mobile = 2, default = 4 },
				aspectRatio = 4 / 3,
				gap = "Space2",
				children = cards,
			}),
		}
	end,
}
