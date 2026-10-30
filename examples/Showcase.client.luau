--[[
	Showcase: a title screen, a component gallery, a pause modal and toasts.
	Copy into StarterPlayerScripts (or run in the dev place) to try Lucy.
	Keys: Tab / arrows / Enter to navigate, Escape or ButtonB to go back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Lucy = require(ReplicatedStorage:WaitForChild("Lucy"))

local app = Lucy.App.new({ theme = "dark", baseColor = "zinc", primary = "violet" })

local function centered(parent, width)
	local holder = Lucy.Component.box({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
	return holder
end

app.scenes:register("Title", {
	build = function(scene)
		local holder = centered(scene.gui, 420)
		scene.play = Lucy.Button.new({
			id = "play",
			text = "Play",
			size = "lg",
			onClick = function()
				app.scenes:goTo("Gallery")
			end,
		})
		Lucy.Stack.new({
			Parent = holder,
			gap = "Space4",
			align = "center",
			children = {
				Lucy.Text.new({ text = "Lucy", variant = "h1", align = "center" }),
				Lucy.Text.new({ text = "A UI kit for Roblox", variant = "muted", align = "center" }),
				Lucy.Stack.new({
					direction = { mobile = "vertical", default = "horizontal" },
					gap = "Space2",
					children = {
						scene.play,
						Lucy.Button.new({
							text = "Toggle theme",
							variant = "outline",
							size = "lg",
							onClick = function()
								app:setTheme(if app.theme:get() == "dark" then "light" else "dark")
							end,
						}),
					},
				}),
			},
		})
	end,
	defaultFocus = function(scene)
		return scene.play
	end,
})

app.scenes:register("Gallery", {
	build = function(scene)
		local holder = centered(scene.gui, 560)
		local quit = Lucy.Dialog.new({
			id = "quit",
			title = "Leave the gallery?",
			description = "You can come back any time.",
			actions = {
				{ text = "Stay", variant = "outline" },
				{
					text = "Leave",
					variant = "destructive",
					onClick = function()
						app.scenes:goTo("Title")
					end,
				},
			},
		})
		scene.maid:give(quit)

		scene.first = Lucy.Button.new({
			text = "Toast",
			onClick = function()
				app.toast.success("Saved", { description = "Loadout stored" })
			end,
		})
		Lucy.Panel.new({
			Parent = holder,
			title = "Components",
			description = "Mouse, keyboard, gamepad and touch.",
			children = {
				Lucy.Stack.new({
					direction = "horizontal",
					gap = "Space2",
					children = {
						Lucy.Badge.new({ text = "New" }),
						Lucy.Badge.new({ text = "Beta", variant = "secondary" }),
						Lucy.Badge.new({ text = "Hot", variant = "destructive" }),
						Lucy.Badge.new({ text = "v0.1", variant = "outline" }),
					},
				}),
				Lucy.Input.new({ id = "name", placeholder = "Display name" }),
				Lucy.Checkbox.new({ id = "mute", label = "Mute music" }),
				Lucy.Switch.new({ id = "hints", label = "Show hints", checked = true }),
				Lucy.Progress.new({ id = "xp", value = 64 }),
				Lucy.Separator.new({}),
				Lucy.Skeleton.new({ size = UDim2.new(1, 0, 0, 16) }),
			},
			footer = {
				scene.first,
				Lucy.Button.new({
					text = "Leave",
					variant = "ghost",
					onClick = function()
						quit:open()
					end,
				}),
			},
		})
	end,
	defaultFocus = function(scene)
		return scene.first
	end,
	onBack = function()
		app.state:set("ui.quit.open", true)
	end,
})

app.scenes:goTo("Title")

-- Live readout of what Lucy thinks the player is using.
app.state:subscribe("input", function(input)
	print(`[Lucy showcase] device={input.device} mode={input.mode} density={app.theme:getDensity()}`)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.T then
		app.toast.info("Tip", { description = "Press Escape to go back" })
	end
end)
