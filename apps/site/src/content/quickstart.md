```luau [UI.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

-- One app per player. Its state holds your game's data, and the theme.
local app = Lucy.App.new({
	theme = "dark",
	state = { settings = { volume = 50 } },
})

app.scenes:register("Settings", {
	build = function(scene)
		Lucy.Stack.new({
			size = UDim2.fromScale(1, 1),
			align = "center",
			justify = "center",
			children = {
				Lucy.Panel.new({
					title = "Settings",
					maxWidth = 400,
					children = {
						-- Each control is bound to a value in state, both ways.
						Lucy.Text.new({ text = "Volume", variant = "label" }),
						Lucy.Slider.new({ value = app.state:ref("settings.volume"), showValue = true }),
						Lucy.Text.new({ text = "Theme", variant = "label" }),
						Lucy.Select.new({
							items = { { value = "dark", label = "Dark" }, { value = "light", label = "Light" } },
							value = app.state:ref("theme"), -- pick Light and the whole UI switches
						}),
					},
				}),
			},
			Parent = scene.gui,
		})
	end,
})

app.scenes:goTo("Settings")

-- The game reads the same state. No glue code in between.
app.state:subscribe("settings.volume", function(volume)
	SoundService.Music.Volume = volume / 100
end)
```
