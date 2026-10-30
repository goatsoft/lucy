--[[
	Lucy: a UI kit and app framework for Roblox.

		local Lucy = require(ReplicatedStorage.Packages.Lucy)
		local app = Lucy.App.new({ theme = "dark", baseColor = "zinc" })

		app.scenes:register("Title", { build = function(scene)
			Lucy.Button.new({ text = "Play", Parent = scene.gui, onClick = function()
				app.scenes:goTo("Game")
			end })
		end })
		app.scenes:goTo("Title")
		app.toast.success("Welcome back")

	See README.md and docs/ for the full guide.
]]

local Core = script.Core
local Components = script.Components

return {
	-- Framework
	App = require(Core.App),
	AppState = require(Core.AppState),
	Theme = require(Core.Theme),
	Tokens = require(Core.Tokens),
	Oklab = require(Core.Oklab),
	Palette = require(Core.Palette),
	SceneManager = require(Core.SceneManager),
	InputManager = require(Core.InputManager),
	Adaptive = require(Core.Adaptive),
	Responsive = require(Core.Responsive),
	Component = require(Core.Component),
	Signal = require(Core.Signal),
	Maid = require(Core.Maid),

	-- Components
	Badge = require(Components.Badge),
	Button = require(Components.Button),
	Checkbox = require(Components.Checkbox),
	Dialog = require(Components.Dialog),
	Input = require(Components.Input),
	Panel = require(Components.Panel),
	Progress = require(Components.Progress),
	Separator = require(Components.Separator),
	Skeleton = require(Components.Skeleton),
	Stack = require(Components.Stack),
	Switch = require(Components.Switch),
	Text = require(Components.Text),
	Toaster = require(Components.Toaster),
}
