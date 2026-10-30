return {
	group = "Components",
	description = "Pick one difficulty. The last option is locked.",
	width = 360,
	controls = {
		orientation = { "vertical", "horizontal" },
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local level = Lucy.ref("normal")
		return Lucy.new("Frame")({
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			function()
				return Lucy.Stack.new({
					gap = "Space3",
					children = {
						Lucy.RadioGroup.new({
							orientation = c.orientation(),
							value = level,
							disabled = c.disabled,
							items = {
								{ value = "easy", label = "Easy" },
								{ value = "normal", label = "Normal" },
								{ value = "hard", label = "Hard" },
								{
									value = "expert",
									label = "Expert (win a hard round first)",
									disabled = true,
								},
							},
						}),
						Lucy.Text.new({
							variant = "muted",
							text = function()
								return `Difficulty: {level()}`
							end,
						}),
					},
				})
			end,
		})
	end,
}
