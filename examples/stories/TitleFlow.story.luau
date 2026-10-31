--[[
	Scenes in a story: a title screen, a lobby and a pause modal on the story's own
	App. The controls drive the scene manager and follow it back (Backspace or ButtonB
	pops the pause modal, which clears `paused`).
]]
return {
	title = "Title flow",
	group = "Scenes",
	description = "Screens and a modal driven by the scene manager.",
	layout = "fullscreen",
	controls = {
		screen = { "Title", "Lobby" },
		paused = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local app = ctx.app
		local c = ctx.controls

		local function centered(parent, width)
			return Lucy.Component.box({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(width, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = parent,
			})
		end

		app.scenes:register("Title", {
			build = function(scene)
				scene.play = Lucy.Button.new({
					text = "Play",
					size = "lg",
					onClick = function()
						c.screen("Lobby")
					end,
				})
				Lucy.Stack.new({
					Parent = centered(scene.gui, 420),
					gap = "Space4",
					align = "center",
					children = {
						Lucy.Text.new({ text = "Lucy", variant = "h1", align = "center" }),
						Lucy.Text.new({ text = "A UI kit for Roblox", variant = "muted", align = "center" }),
						scene.play,
					},
				})
			end,
			defaultFocus = function(scene)
				return scene.play
			end,
		})

		app.scenes:register("Lobby", {
			build = function(scene)
				scene.ready = Lucy.Button.new({ text = "Ready" })
				Lucy.Panel.new({
					Parent = centered(scene.gui, 420),
					title = "Lobby",
					description = "Waiting for players.",
					children = {
						Lucy.Progress.new({ value = 60 }),
						Lucy.Switch.new({ label = "Voice chat", checked = true }),
					},
					footer = {
						scene.ready,
						Lucy.Button.new({
							text = "Pause",
							variant = "outline",
							onClick = function()
								c.paused(true)
							end,
						}),
					},
				})
			end,
			defaultFocus = function(scene)
				return scene.ready
			end,
			onBack = function()
				c.screen("Title")
			end,
		})

		app.scenes:register("Pause", {
			layer = "modal",
			build = function(scene)
				Lucy.new("Frame")({
					Name = "Scrim",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					Parent = scene.gui,
				})
				scene.resume = Lucy.Button.new({
					text = "Resume",
					onClick = function()
						c.paused(false)
					end,
				})
				Lucy.Panel.new({
					Parent = centered(scene.gui, 320),
					title = "Paused",
					footer = {
						scene.resume,
						Lucy.Button.new({
							text = "Quit to title",
							variant = "ghost",
							onClick = function()
								c.paused(false)
								c.screen("Title")
							end,
						}),
					},
				})
			end,
			defaultFocus = function(scene)
				return scene.resume
			end,
		})

		-- Controls drive the scene manager...
		Lucy.watch(c.screen, function(name)
			app.scenes:goTo(name)
		end, { immediate = true })
		Lucy.watch(c.paused, function(paused)
			local stack = app.state:get("scenes.stack") or {}
			local open = table.find(stack, "Pause") ~= nil
			if paused and not open then
				app.scenes:push("Pause")
			elseif not paused and open then
				app.scenes:pop()
			end
		end, { immediate = true })
		-- ...and follow it back when the player navigates (back, Backspace, ButtonB).
		local stack = app.state:ref("scenes.stack")
		-- Only the stack is tracked, so this never races the push above.
		Lucy.watchEffect(function()
			local open = table.find(stack() or {}, "Pause") ~= nil
			Lucy.untrack(function()
				if c.paused() ~= open then
					c.paused(open)
				end
			end)
		end)
	end,
}
