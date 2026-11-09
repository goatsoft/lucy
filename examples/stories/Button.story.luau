return {
	group = "Components",
	description = "Every variant and size; the top button follows the controls.",
	width = 520,
	controls = {
		text = "Play",
		variant = { "default", "secondary", "outline", "ghost", "destructive", "link" },
		size = { options = { "sm", "md", "lg" }, default = "md" },
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local row = {}
		for _, variant in { "default", "secondary", "outline", "ghost", "destructive", "link" } do
			table.insert(row, Lucy.Button.new({ text = variant, variant = variant, size = "sm" }))
		end
		return {
			Lucy.Button.new({
				text = c.text,
				variant = c.variant,
				size = c.size,
				disabled = c.disabled,
				onClick = function()
					ctx.app.toast(`Clicked {c.text()}`)
				end,
			}),
			-- The slot: an icon and a price after the text, in the button's colours
			Lucy.Button.new({
				text = "UNLOCK",
				variant = c.variant,
				disabled = c.disabled,
				children = { Lucy.Icon.new({ icon = "lucide-extended:coins-filled" }), "199" },
			}),
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space2",
				wrap = true,
				justify = "center",
				size = UDim2.fromScale(1, 0),
				automaticSize = Enum.AutomaticSize.Y,
				children = row,
			}),
		}
	end,
}
