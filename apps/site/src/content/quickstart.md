```luau [UI.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local app = Lucy.App.new({
	theme = "dark",
	baseColor = "zinc",
	primary = "violet",
	state = { player = { coins = 0 } },
})

local coins = app.state:ref("player.coins")

app.scenes:register("Title", {
	build = function(scene)
		scene.play = Lucy.Button.new({
			id = "play",
			text = "Play",
			size = "lg",
			onClick = function()
				app.scenes:goTo("Game")
			end,
		})
		Lucy.Stack.new({
			size = UDim2.fromScale(1, 1),
			align = "center",
			justify = "center",
			gap = "Space6",
			children = {
				Lucy.Text.new({ text = "My Game", variant = "h1", align = "center" }),
				scene.play,
			},
			Parent = scene.gui,
		})
	end,
	defaultFocus = function(scene)
		return scene.play -- selected first on keyboard or gamepad
	end,
})

app.scenes:register("Game", {
	build = function(scene)
		Lucy.Stack.new({
			padding = "Space6",
			children = {
				Lucy.Text.new({
					text = function()
						return `Coins: {coins()}`
					end,
					variant = "h3",
				}),
			},
			Parent = scene.gui,
		})
	end,
	enter = function()
		app.toast.success("Round started", { description = "Collect coins to win" })
	end,
	onBack = function()
		app.scenes:goTo("Title") -- Escape or ButtonB
	end,
})

app.scenes:goTo("Title")

-- Game code changes state and the label follows.
coins(coins() + 10)
```
