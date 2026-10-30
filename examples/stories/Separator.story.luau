return {
	group = "Components",
	description = "Horizontal and vertical rules.",
	render = function(ctx)
		local Lucy = ctx.Lucy
		local function word(text)
			return Lucy.Text.new({ text = text, variant = "small", autoWidth = true })
		end
		return {
			Lucy.Text.new({ text = "Lucy", variant = "h4" }),
			Lucy.Text.new({ text = "A UI kit for Roblox", variant = "muted" }),
			Lucy.Separator.new({}),
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space4",
				align = "center",
				size = UDim2.new(1, 0, 0, 20),
				children = {
					word("Docs"),
					Lucy.Separator.new({ orientation = "vertical" }),
					word("Components"),
					Lucy.Separator.new({ orientation = "vertical" }),
					word("Source"),
				},
			}),
		}
	end,
}
