return {
	group = "Components",
	description = "A club's top dancers: medals for the top three, your row lit, or pinned when you are not listed.",
	width = 420,
	controls = {
		size = { options = { "sm", "md", "lg" }, default = "md" },
		listed = false,
		loading = false,
		empty = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local names = { "Nova", "Blaze", "Echo", "Pixel", "Rogue", "Sky", "Vex", "Zed" }
		local rows = {}
		for i, name in names do
			table.insert(rows, { userId = -i, name = name, value = math.floor(16000 / i) })
		end
		return {
			Lucy.Leaderboard.new({
				size = c.size,
				rows = function()
					return if c.empty() then {} else rows
				end,
				own = function()
					return if c.listed()
						then { userId = -4, name = "Pixel", value = 4000, rank = 4 }
						else { userId = -99, name = "You", value = 320, rank = 37 }
				end,
				loading = c.loading,
				format = function(value: number)
					return `{Lucy.Leaderboard.formatNumber(value)} PTS`
				end,
				empty = "No one has danced yet. Be the first.",
			}),
		}
	end,
}
