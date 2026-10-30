return {
	group = "Components",
	description = "app.toast with each kind. One toast is shown on mount.",
	controls = {
		kind = { "success", "default", "info", "warning", "error" },
		title = "Round won",
		description = "+$250",
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local function show()
			ctx.app.toast(c.title(), {
				kind = c.kind(),
				description = if c.description() ~= "" then c.description() else nil,
				duration = math.huge,
			})
		end
		show()
		return Lucy.Stack.new({
			direction = "horizontal",
			gap = "Space2",
			justify = "center",
			children = {
				Lucy.Button.new({ text = "Show toast", onClick = show }),
				Lucy.Button.new({
					text = "Dismiss all",
					variant = "outline",
					onClick = function()
						ctx.app.toast.dismiss()
					end,
				}),
			},
		})
	end,
}
