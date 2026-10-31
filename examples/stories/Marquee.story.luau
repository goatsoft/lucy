return {
	group = "Components",
	description = "A line that scrolls when it does not fit; the column is narrow on purpose.",
	width = 260,
	controls = {
		text = "Future Bounce VIP (Extended Club Mix) by DJ GOD",
		variant = { "large", "h3", "p", "muted" },
		visible = true,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		return {
			Lucy.Text.new({ text = "NOW PLAYING", variant = "small" }),
			Lucy.Marquee.new({ id = "now-playing", text = c.text, variant = c.variant, visible = c.visible }),
			Lucy.Marquee.new({ text = "Fits: no scrolling", variant = "muted" }),
		}
	end,
}
