return {
	group = "Components",
	description = "The type scale; the first line follows the controls.",
	width = 480,
	controls = {
		text = "Turf Heist",
		variant = { "h1", "h2", "h3", "h4", "p", "lead", "large", "small", "muted", "label" },
		align = { "center", "left", "right" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local items =
			{ Lucy.Text.new({ text = c.text, variant = c.variant, align = c.align }), Lucy.Separator.new({}) }
		for _, variant in { "h2", "h4", "p", "muted" } do
			table.insert(items, Lucy.Text.new({ text = `{variant}: the quick brown fox`, variant = variant }))
		end
		return items
	end,
}
