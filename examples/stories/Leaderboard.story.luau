return {
	group = "Components",
	description = "Club Lucy's hype board: 1st up top, 2nd and 3rd under it, the rest by name, and you pinned at the bottom.",
	width = 460,
	controls = {
		size = { options = { "sm", "md", "lg" }, default = "md" },
		listed = false,
		loading = false,
		empty = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local crew = {
			{ name = "Nova", hype = 9840 },
			{ name = "DJ Lucy", hype = 9125 },
			{ name = "Kai", hype = 8410 },
			{ name = "Juno", hype = 7360 },
			{ name = "Beatrix", hype = 6220 },
			{ name = "Remy", hype = 5480 },
		}
		local rows = {}
		for i, dancer in crew do
			table.insert(rows, { userId = -i, name = dancer.name, value = dancer.hype })
		end
		return {
			Lucy.Leaderboard.new({
				size = c.size,
				rows = function()
					return if c.empty() then {} else rows
				end,
				own = function()
					return if c.listed()
						then { userId = -4, name = "Juno", value = 7360, rank = 4 }
						else { userId = -99, name = "You", value = 1250, rank = 37 }
				end,
				loading = c.loading,
				medals = {
					"lucide-extended:crown-filled",
					"lucide-extended:crown-filled",
					"lucide-extended:crown-filled",
				},
				format = function(value: number)
					return `{Lucy.Leaderboard.formatNumber(value)} hype`
				end,
				empty = "No hype yet. Get on the Dance Floor.",
				height = 360,
			}),
		}
	end,
}
