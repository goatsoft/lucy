return {
	group = "Components",
	description = "A DJ booth with three tabs. Each panel keeps its state when you switch away.",
	width = 480,
	controls = {
		variant = { "default", "outline" },
		size = { options = { "sm", "md", "lg" }, default = "md" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local function songs()
			local rows = {}
			for i = 1, 12 do
				table.insert(
					rows,
					Lucy.Pressable.new({
						size = UDim2.new(1, 0, 0, 36),
						padding = "Space2",
						children = { Lucy.Text.new({ text = `Song {i}` }) },
					})
				)
			end
			return Lucy.ScrollArea.new({
				maxHeight = 200,
				children = { Lucy.Stack.new({ gap = "Space1", children = rows }) },
			})
		end
		return {
			Lucy.Tabs.new({
				variant = c.variant,
				size = c.size,
				items = {
					{ value = "queue", text = "Queue", content = songs },
					{
						value = "effects",
						text = "Effects",
						content = function()
							return Lucy.Stack.new({
								gap = "Space2",
								children = {
									Lucy.Switch.new({ label = "Echo" }),
									Lucy.Switch.new({ label = "Strobe lights" }),
								},
							})
						end,
					},
					{
						value = "about",
						text = "About",
						content = function()
							return Lucy.Text.new({
								text = "Pick songs for the next round.",
								variant = "muted",
							})
						end,
					},
				},
			}),
		}
	end,
}
