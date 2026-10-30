return {
	group = "Components",
	description = "Pick one option from a list: under the button on mouse and gamepad, from the bottom on touch.",
	width = 320,
	controls = {
		input = { "mouse", "touch", "gamepad" },
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		-- Preview only: pretend the player switched input.
		Lucy.watch(ctx.controls.input, function(mode)
			ctx.app.input:setMode(mode)
		end, { immediate = true })

		local servers = {}
		for _, name in
			{
				"Sydney",
				"Singapore",
				"Tokyo",
				"Frankfurt",
				"London",
				"Virginia",
				"Oregon",
				"Sao Paulo",
				"Mumbai",
			}
		do
			table.insert(servers, name)
		end

		return {
			Lucy.Stack.new({
				gap = "Space4",
				children = {
					Lucy.Select.new({
						placeholder = "Game mode",
						disabled = ctx.controls.disabled,
						items = {
							{ value = "solo", label = "Solo" },
							{ value = "duos", label = "Duos" },
							{ value = "squads", label = "Squads" },
							{ value = "ranked", label = "Ranked", disabled = true },
						},
						layoutOrder = 1,
					}),
					Lucy.Select.new({
						value = "Sydney",
						disabled = ctx.controls.disabled,
						items = servers,
						onValueChange = function(value)
							ctx.app.toast("Server: " .. tostring(value))
						end,
						layoutOrder = 2,
					}),
					Lucy.Select.new({
						type = "check",
						value = "medium",
						disabled = ctx.controls.disabled,
						items = {
							{ value = "low", label = "Low quality" },
							{ value = "medium", label = "Medium quality" },
							{ value = "high", label = "High quality" },
						},
						layoutOrder = 3,
					}),
					Lucy.Select.new({
						multiple = true,
						value = { "pop", "house" },
						placeholder = "Genres",
						disabled = ctx.controls.disabled,
						items = {
							{ value = "pop", label = "Pop" },
							{ value = "hiphop", label = "Hip hop" },
							{ value = "house", label = "House" },
							{ value = "kpop", label = "K-pop" },
							{ value = "rock", label = "Rock" },
						},
						layoutOrder = 4,
					}),
				},
			}),
		}
	end,
}
