return {
	group = "Components",
	description = "A loading card. Toggle loaded to swap in the real content.",
	controls = {
		loaded = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		return Lucy.new("Frame")({
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Lucy.show(ctx.controls.loaded, function()
				return Lucy.Panel.new({ title = "JB", description = "Online, in Turf Heist" })
			end, function()
				return Lucy.Stack.new({
					direction = "horizontal",
					gap = "Space4",
					align = "center",
					children = {
						Lucy.Skeleton.new({ size = UDim2.fromOffset(48, 48), circle = true }),
						Lucy.Stack.new({
							gap = "Space2",
							size = UDim2.fromOffset(250, 0),
							children = {
								Lucy.Skeleton.new({ size = UDim2.new(1, 0, 0, 16) }),
								Lucy.Skeleton.new({ size = UDim2.new(0.7, 0, 0, 16) }),
							},
						}),
					},
				})
			end),
		})
	end,
}
