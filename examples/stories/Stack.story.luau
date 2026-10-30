return {
	group = "Components",
	description = "Layout props are plain values, so the stack is rebuilt when a control changes.",
	width = 480,
	controls = {
		direction = { "horizontal", "vertical" },
		gap = { options = { "Space1", "Space2", "Space4", "Space6" }, default = "Space2" },
		align = { "start", "center", "end" },
		justify = { "start", "center", "end", "between" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		return Lucy.new("Frame")({
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			function()
				return Lucy.Stack.new({
					direction = c.direction(),
					gap = c.gap(),
					align = c.align(),
					justify = c.justify(),
					size = if c.direction() == "horizontal" then UDim2.new(1, 0, 0, 48) else nil,
					children = {
						Lucy.Button.new({ text = "One", size = "sm" }),
						Lucy.Button.new({ text = "Two", size = "sm", variant = "secondary" }),
						Lucy.Button.new({ text = "Three", size = "sm", variant = "outline" }),
					},
				})
			end,
		})
	end,
}
