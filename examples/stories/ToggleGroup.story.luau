return {
	group = "Components",
	description = "Genre chips (pick several) and a 1 to 5 vote (pick one).",
	width = 480,
	controls = {
		variant = { "default", "outline" },
		size = { options = { "sm", "md", "lg" }, default = "md" },
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local genres = Lucy.ref({ "House" })
		local vote = Lucy.ref(false)
		return {
			Lucy.Stack.new({
				gap = "Space4",
				children = {
					Lucy.ToggleGroup.new({
						type = "multiple",
						items = { "House", "Techno", { value = "hiphop", text = "Hip hop" }, "Pop" },
						value = genres,
						variant = c.variant,
						size = c.size,
						disabled = c.disabled,
					}),
					Lucy.Text.new({
						variant = "muted",
						text = function()
							local picked = genres()
							return if #picked == 0 then "All genres" else table.concat(picked, ", ")
						end,
					}),
					Lucy.ToggleGroup.new({
						items = { 1, 2, 3, 4, 5 },
						value = vote,
						variant = c.variant,
						size = c.size,
						disabled = c.disabled,
					}),
					Lucy.Text.new({
						variant = "muted",
						text = function()
							local stars = vote()
							return if stars then `You voted {stars}` else "Not voted yet"
						end,
					}),
				},
			}),
		}
	end,
}
