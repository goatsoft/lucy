```luau [UI.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

-- One app per player. Its state holds your game's data.
local app = Lucy.App.new({
	theme = "dark",
	state = { coins = 0 },
})

-- coins() reads the value, coins(10) writes it.
local coins = app.state:ref("coins")

app.scenes:register("Hud", {
	build = function(scene)
		Lucy.Stack.new({
			direction = "horizontal",
			align = "center",
			gap = "Space4",
			padding = "Space6",
			children = {
				Lucy.Text.new({
					-- A function is followed: the label updates when coins changes.
					text = function()
						return `Coins: {coins()}`
					end,
					variant = "h3",
					autoWidth = true,
				}),
				Lucy.Button.new({
					id = "collect", -- its state lives at ui.collect
					text = "Collect 10",
					onClick = function()
						coins(coins() + 10)
					end,
				}),
			},
			Parent = scene.gui,
		})
	end,
})

app.scenes:goTo("Hud")

-- Change state from anywhere in your game and the UI follows.
app.state:set("coins", 100)
```
