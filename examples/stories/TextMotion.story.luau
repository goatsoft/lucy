local LINES = {
	"Hi, I'm Lucy! Haven't seen you around here before.",
	"Every dance you learn here is yours to keep.",
	"Wanna hit the stage?",
}

return {
	group = "Components",
	description = "Text that types itself out (useReveal) and a number that counts up (useCount). NEXT LINE and +250 XP play them again.",
	width = 420,
	controls = {
		rate = 34,
		seconds = 0.8,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local index = Lucy.ref(1)
		local xp = Lucy.ref(1200)
		local line = Lucy.Text.new({
			text = function()
				return LINES[index()]
			end,
			variant = "lead",
			reveal = c.rate,
		})
		local total = Lucy.Text.new({
			value = xp,
			count = c.seconds,
			format = function(n)
				return `{Lucy.Format.number(n)} XP`
			end,
			variant = "h2",
			align = "center",
		})
		local revealing = line:ref("revealing")
		return {
			Lucy.Stack.new({
				gap = "Space4",
				children = {
					line,
					Lucy.Button.new({
						text = function()
							return if revealing() then "SKIP" else "NEXT LINE"
						end,
						variant = "outline",
						onClick = function()
							if revealing() then
								line:skipReveal()
							else
								index(index() % #LINES + 1)
							end
						end,
					}),
					Lucy.Separator.new({}),
					total,
					Lucy.Button.new({
						text = "+250 XP",
						variant = "outline",
						onClick = function()
							xp(xp() + 250)
						end,
					}),
				},
			}),
		}
	end,
}
