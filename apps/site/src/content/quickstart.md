```luau [UI.client.luau]
local Lucy = require(ReplicatedStorage.Shared.Lucy)
local app = Lucy.App.new({ theme = "dark", baseColor = "zinc", primary = "violet" })

app.scenes:register("Title", {
	build = function(scene)
		scene.play = Lucy.Button.new({
			id = "play", text = "Play", size = "lg", Parent = scene.gui,
			onClick = function() app.scenes:goTo("Game") end,
		})
	end,
	defaultFocus = function(scene) return scene.play end,
})
app.scenes:goTo("Title")

app.state:set("ui.play.disabled", true) -- drive any component from anywhere
app.toast.success("Welcome back", { description = "Daily reward ready" })
```
