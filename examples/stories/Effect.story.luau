return {
	group = "Components",
	description = "An animated celebration behind a reward. PLAY plays its opening again.",
	width = 360,
	controls = {
		variant = { "primary", "warning", "success", "foreground" },
		visible = true,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local reward = Lucy.new("Frame")({
			Size = UDim2.fromOffset(240, 240),
			BackgroundTransparency = 1,
		})
		local effect =
			Lucy.Effect.new({ type = "rays", variant = c.variant, visible = c.visible, Parent = reward })
		local gift = Lucy.Icon.new({ icon = "lucide:gift", size = "lg" })
		Lucy.hydrate(gift.Instance)({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 2,
			Parent = reward,
		})
		return {
			Lucy.Stack.new({
				gap = "Space4",
				align = "center",
				children = {
					reward,
					Lucy.Button.new({
						text = "PLAY",
						variant = "outline",
						onClick = function()
							effect:play()
						end,
					}),
				},
			}),
		}
	end,
}
