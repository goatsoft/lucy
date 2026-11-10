return {
	group = "Components",
	description = "Actions that open as a list, a ring or a fan and close once one is picked; each input can get its own shape.",
	width = 520,
	height = 420,
	controls = {
		input = { "mouse", "gamepad", "touch" },
		variant = { "by input", "list", "radial", "arc" },
		shape = { "round", "squircle", "square" },
		-- The first item follows it (Join / Leave show) and Items fades out while in the show
		inShow = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		-- Preview only: pretend the player switched input.
		Lucy.watch(ctx.controls.input, function(mode)
			ctx.app.input:setMode(mode)
		end, { immediate = true })

		local ITEMS = {
			{
				value = "join",
				label = function()
					return if ctx.controls.inShow() then "Leave show" else "Join show"
				end,
				icon = function()
					return if ctx.controls.inShow() then "lucy:minus" else "lucy:plus"
				end,
			},
			{ value = "dj", label = "DJ request" },
			{ value = "lab", label = "The Lab" },
			{ value = "dances", label = "Dances" },
			{ value = "items", label = "Items", disabled = ctx.controls.inShow },
			{ value = "exit", label = "Exit", icon = "lucy:close" },
		}

		local function variant(): any
			local picked = ctx.controls.variant()
			if picked == "by input" then
				return { gamepad = "radial", touch = "arc", default = "list" }
			end
			return picked
		end

		-- A Menu's variant and shape are fixed when it is made, so the story makes one per choice.
		local holder = Lucy.new("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		})
		local current = nil
		Lucy.watch(function()
			return `{ctx.controls.variant()}/{ctx.controls.shape()}`
		end, function()
			if current then
				current.menu:destroy()
				current.button:destroy()
			end
			local button = Lucy.Button.new({
				text = "Menu",
				variant = "outline",
				Parent = holder,
			})
			button.Instance.AnchorPoint = Vector2.new(1, 1)
			button.Instance.Position = UDim2.new(1, -16, 1, -16)
			local menu = Lucy.Menu.new({
				items = ITEMS,
				variant = variant(),
				shape = ctx.controls.shape(),
				anchor = button,
				onSelect = function(value)
					ctx.app.toast(`Picked {value}`)
				end,
				Parent = holder,
			})
			button.Activated:Connect(function()
				menu:toggle()
			end)
			current = { menu = menu, button = button }
		end, { immediate = true })

		return { holder }
	end,
}
