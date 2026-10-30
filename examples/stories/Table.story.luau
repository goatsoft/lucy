return {
	group = "Components",
	description = "A leaderboard of 500 players: only the rows near the view are built. Your row is highlighted.",
	width = 560,
	controls = {
		striped = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local names = { "Nova", "Blaze", "Echo", "Pixel", "Rogue", "Sky", "Vex", "Zed", "Luna", "Orbit" }
		local players = {}
		for i = 1, 500 do
			table.insert(players, {
				userId = i,
				rank = i,
				name = names[(i - 1) % #names + 1] .. i,
				wins = math.max(0, 900 - i * 2 + (i * 37) % 23),
				score = 100000 - i * 173,
			})
		end
		local me = 7

		return {
			Lucy.Table.new({
				rows = players,
				rowId = function(player)
					return player.userId
				end,
				columns = {
					{
						key = "rank",
						header = "#",
						width = 56,
						align = "center",
						cell = function(cell)
							local rank = cell.value()
							if rank <= 3 then
								return Lucy.Badge.new({
									text = tostring(rank),
									variant = if rank == 1 then "default" else "secondary",
								})
							end
							return tostring(rank)
						end,
					},
					{ key = "name", header = "Player", width = { fill = 2 } },
					{ key = "wins", header = "Wins", width = { fill = 1 }, align = "right" },
					{ key = "score", header = "Score", width = { fill = 1 }, align = "right" },
				},
				striped = ctx.controls.striped,
				highlight = function(player)
					return player.userId == me
				end,
				onRowClick = function(player)
					ctx.app.toast("Viewing " .. player.name)
				end,
				virtual = true,
				rowHeight = 40,
				maxHeight = 360,
			}),
		}
	end,
}
