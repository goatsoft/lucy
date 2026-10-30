return {
	group = "Components",
	description = "A shop you can sort: press a header to sort by it, again to flip it, again to clear it.",
	width = 560,
	render = function(ctx)
		local Lucy = ctx.Lucy
		local rarityOrder = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }
		local items = {
			{ id = "glow", name = "Glow Sticks", rarity = "Common", price = 50, owned = 3 },
			{ id = "crown", name = "Neon Crown", rarity = "Legendary", price = 2500, owned = 0 },
			{ id = "wings", name = "Laser Wings", rarity = "Epic", price = 1200, owned = 1 },
			{ id = "shades", name = "DJ Shades", rarity = "Rare", price = 400, owned = 2 },
			{ id = "boots", name = "Moon Boots", rarity = "Rare", price = 650, owned = 0 },
			{ id = "cape", name = "Disco Cape", rarity = "Epic", price = 900, owned = 0 },
			{ id = "cap", name = "Snapback", rarity = "Common", price = 120, owned = 5 },
		}

		return {
			Lucy.DataGrid.new({
				data = items,
				rowId = function(item)
					return item.id
				end,
				columns = {
					{ key = "name", header = "Item", width = { fill = 2 } },
					{
						key = "rarity",
						header = "Rarity",
						width = { fill = 1 },
						descFirst = true,
						sortFn = function(a, b)
							return rarityOrder[a] - rarityOrder[b]
						end,
						cell = function(cell)
							local rarity = cell.value()
							return Lucy.Badge.new({
								text = rarity,
								variant = if rarity == "Legendary" or rarity == "Epic"
									then "default"
									else "secondary",
							})
						end,
					},
					{ key = "price", header = "Price", width = 96, align = "right", descFirst = true },
					{ key = "owned", header = "Owned", width = 88, align = "right" },
				},
				sorting = { id = "price", desc = true },
				striped = true,
				onRowClick = function(item)
					ctx.app.toast("Buy " .. item.name .. "?")
				end,
			}),
		}
	end,
}
