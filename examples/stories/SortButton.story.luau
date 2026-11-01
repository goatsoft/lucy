return {
	group = "Components",
	description = "Headings over a list of emotes. Rarity leads; press Name to break its ties, press again to flip, a third time to drop it.",
	width = 420,
	render = function(ctx)
		local Lucy = ctx.Lucy
		local rarityOrder = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }
		local emotes = {
			{ name = "Moonwalk", style = "Pop", rarity = "Legendary" },
			{ name = "Robot", style = "Electro", rarity = "Rare" },
			{ name = "Shuffle", style = "House", rarity = "Common" },
			{ name = "Floss", style = "Pop", rarity = "Rare" },
			{ name = "Windmill", style = "Breaking", rarity = "Epic" },
			{ name = "Twist", style = "Pop", rarity = "Common" },
			{ name = "Headspin", style = "Breaking", rarity = "Legendary" },
		}

		local sorted = Lucy.useSort({
			data = emotes,
			columns = {
				{ key = "name", header = "Name" },
				{ key = "style", header = "Style" },
				{
					key = "rarity",
					header = "Rarity",
					descFirst = true,
					sortFn = function(a, b)
						return rarityOrder[a] - rarityOrder[b]
					end,
				},
			},
			sorting = { { id = "rarity", desc = true } },
			multi = true,
		})

		local function heading(column: string)
			return Lucy.SortButton.new({ sort = sorted, column = column, size = UDim2.new(1 / 3, -8, 0, 32) })
		end

		return {
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space3",
				size = UDim2.fromScale(1, 0),
				automaticSize = Enum.AutomaticSize.Y,
				children = { heading("name"), heading("style"), heading("rarity") },
			}),
			Lucy.Separator.new({}),
			Lucy.new("Frame")({
				Name = "Emotes",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Lucy.new("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
				Lucy.each(sorted.items, function(emote: any, index: () -> number)
					local row = Lucy.Text.new({
						text = `{emote.name} · {emote.style} · {emote.rarity}`,
						variant = "small",
					})
					Lucy.hydrate(row.Instance)({ LayoutOrder = index })
					return row
				end, {
					key = function(emote: any)
						return emote.name
					end,
				}),
			}),
		}
	end,
}
