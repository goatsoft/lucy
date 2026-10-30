return {
	group = "Components",
	description = "Buttons that stay pressed. Click one to turn it on or off.",
	width = 420,
	controls = {
		variant = { "default", "outline" },
		size = { options = { "sm", "md", "lg" }, default = "md" },
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local toggles = {}
		for _, name in { "Music", "Effects", "Voice chat" } do
			table.insert(
				toggles,
				Lucy.Toggle.new({
					text = name,
					pressed = name == "Music",
					variant = c.variant,
					size = c.size,
					disabled = c.disabled,
				})
			)
		end
		return {
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space2",
				align = "center",
				children = toggles,
			}),
		}
	end,
}
