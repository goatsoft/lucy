return {
	group = "Components",
	description = "List rows with media, a title, a description and actions. Click a song to pick it.",
	width = 480,
	controls = {
		variant = { "outline", "default", "muted" },
		size = { "md", "sm" },
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local picked = Lucy.ref("Night Drive")
		local colours =
			{ Color3.fromRGB(6, 182, 212), Color3.fromRGB(168, 85, 247), Color3.fromRGB(236, 72, 153) }
		local songs = {
			{ "Night Drive", "Synthwave, 118 BPM" },
			{ "Warehouse", "Techno, 132 BPM" },
			{ "Bubblegum", "Pop, 124 BPM" },
		}
		local rows = {}
		for i, song in songs do
			local cover = Lucy.new("Frame")({
				Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = colours[i],
				Lucy.new("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			})
			table.insert(
				rows,
				Lucy.Item.new({
					title = song[1],
					description = song[2],
					media = cover,
					variant = ctx.controls.variant,
					size = ctx.controls.size,
					disabled = ctx.controls.disabled,
					selected = function()
						return picked() == song[1]
					end,
					onClick = function()
						picked(song[1])
					end,
				})
			)
		end
		return {
			Lucy.Stack.new({
				gap = "Space2",
				children = {
					Lucy.Stack.new({ gap = "Space2", children = rows }),
					Lucy.Item.new({
						title = "Streamer mode",
						description = "Plays only music that is safe to stream.",
						variant = ctx.controls.variant,
						size = ctx.controls.size,
						actions = { Lucy.Switch.new({}) },
					}),
					Lucy.Item.new({
						title = "Season pass",
						description = "Unlock every move this season.",
						variant = ctx.controls.variant,
						size = ctx.controls.size,
						actions = { Lucy.Button.new({ text = "Buy", size = "sm" }) },
					}),
				},
			}),
		}
	end,
}
