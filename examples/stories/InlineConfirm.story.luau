return {
	group = "Components",
	description = "Lucy.InlineConfirm: CLEAR asks in place. NO or back puts the panel back, YES clears.",
	width = 420,
	controls = {
		question = "Are you sure?",
		yesVariant = { "destructive", "default", "outline" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls

		local moves = Lucy.ref(12)
		local confirm
		confirm = Lucy.InlineConfirm.new({
			question = c.question,
			yesVariant = c.yesVariant,
			children = {
				Lucy.Text.new({
					text = function()
						return `Your routine has {moves()} moves.`
					end,
				}),
				Lucy.Stack.new({
					direction = "horizontal",
					gap = "Space2",
					children = {
						Lucy.Button.new({
							text = "CLEAR",
							variant = "outline",
							size = "sm",
							onClick = function()
								confirm:ask()
							end,
						}),
						Lucy.Button.new({
							text = "ADD A MOVE",
							variant = "secondary",
							size = "sm",
							onClick = function()
								moves(moves() + 1)
							end,
						}),
					},
				}),
			},
			onYes = function()
				moves(0)
			end,
		})
		return Lucy.Panel.new({ children = { confirm } })
	end,
}
