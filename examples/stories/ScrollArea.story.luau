return {
	group = "Components",
	description = "A song list that fits its rows up to 240 pixels, then scrolls. Tab or a gamepad scrolls to the focused row.",
	width = 420,
	controls = {
		rows = { options = { "3", "8", "30" }, default = "8" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		return Lucy.new("Frame")({
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			function()
				local rows = {}
				for i = 1, tonumber(ctx.controls.rows()) or 8 do
					table.insert(
						rows,
						Lucy.Pressable.new({
							size = UDim2.new(1, 0, 0, 40),
							padding = "Space2",
							children = {
								Lucy.Text.new({ text = `Track {i}` }),
							},
						})
					)
				end
				return Lucy.ScrollArea.new({
					maxHeight = 240,
					padding = "Space2",
					children = {
						Lucy.Stack.new({ gap = "Space1", children = rows }),
					},
				})
			end,
		})
	end,
}
