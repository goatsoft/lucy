---
title: Pause menu
description: A pause menu that opens on B or Backspace and from a button, with a dimmed backdrop, options on top, a confirm before leaving, and gameplay keys off while it is open.
order: 3
---

# Pause menu

A title screen, a game screen and a pause menu. On the game screen, B on a
gamepad, Backspace on a keyboard and a Pause button all open the menu. Options
open on top of it, Leave asks first, and gameplay keys and the character stop
while any menu is open.

Escape can't open it: Roblox opens its own menu on Escape, and a game cannot
stop that. See [Known issues](../known-issues.md#escape-always-opens-robloxs-menu).

```luau [StarterPlayerScripts/UI.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local app = Lucy.App.new({
    state = { settings = { showFps = false } },
})

local current = app.state:ref("scenes.current")

-- Gameplay keys, kept apart from menu keys so they can be switched off.
app.actions:define("gameplay", {
    interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
})
app.actions:on("interact", function()
    print("interact")
end)

-- Gameplay keys and the character stop on any screen but the game, and while
-- a menu is open.
Lucy.effectScope():run(function()
    Lucy.useWhile(function()
        return app:modalOpen() or current() ~= "Game"
    end, function()
        return app.actions:disable("gameplay", "movement")
    end)
end)

-- The dimmed backdrop behind the menu, in the theme's scrim colours. It follows
-- the player's background transparency setting.
app.theme:addRules("pause", {
    {
        selector = ".pause-backdrop",
        properties = {
            BackgroundColor3 = "$Overlay",
            BackgroundTransparency = "$OverlayTransparency",
            BorderSizePixel = 0,
        },
    },
})

local function menu(scene, title, children, footer)
    Lucy.new "Frame" { Size = UDim2.fromScale(1, 1), Tags = { "pause-backdrop" }, Parent = scene.gui }
    Lucy.Stack.new({
        size = UDim2.fromScale(1, 1),
        align = "center",
        justify = "center",
        children = {
            Lucy.Panel.new({ title = title, maxWidth = 360, children = children, footer = footer }),
        },
        Parent = scene.gui,
    })
end

app.scenes:register("Title", {
    build = function(scene)
        scene.play = Lucy.Button.new({
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
            gap = "Space4",
            children = { Lucy.Text.new({ text = "My Game", variant = "h1", align = "center" }), scene.play },
            Parent = scene.gui,
        })
    end,
    defaultFocus = function(scene)
        return scene.play
    end,
})

app.scenes:register("Game", {
    build = function(scene)
        -- A button for mouse and touch, showing the key for keyboard and gamepad.
        local pause = Lucy.Button.new({
            icon = "lucide:pause",
            text = "Pause",
            variant = "secondary",
            hint = { keyboard = Enum.KeyCode.Backspace, gamepad = Enum.KeyCode.ButtonB },
            onClick = function()
                app.scenes:push("Pause")
            end,
            Parent = scene.gui,
        })
        pause.Instance.AnchorPoint = Vector2.new(1, 0)
        pause.Instance.Position = UDim2.new(1, -16, 0, 16)
    end,
    -- B and Backspace on the game screen, with nothing open on top.
    onBack = function()
        app.scenes:push("Pause")
    end,
})

app.scenes:register("Pause", {
    layer = "modal",
    build = function(scene)
        scene.resume = Lucy.Button.new({
            text = "Resume",
            onClick = function()
                app.scenes:pop()
            end,
        })
        menu(scene, "Paused", {
            Lucy.Stack.new({
                gap = "Space2",
                children = {
                    scene.resume,
                    Lucy.Button.new({
                        text = "Options",
                        variant = "secondary",
                        onClick = function()
                            app.scenes:push("Options")
                        end,
                    }),
                    Lucy.Button.new({
                        text = "Leave game",
                        variant = "destructive",
                        onClick = function()
                            Lucy.Dialog.alert({
                                title = "Leave the game?",
                                description = "You will go back to the title screen.",
                                confirmText = "Leave",
                                cancelText = "Stay",
                                destructive = true,
                                onConfirm = function()
                                    app.state:set("scenes.stack", {}) -- close every menu
                                    app.scenes:goTo("Title")
                                end,
                            })
                        end,
                    }),
                },
            }),
        })
    end,
    defaultFocus = function(scene)
        return scene.resume
    end,
})

app.scenes:register("Options", {
    layer = "modal",
    build = function(scene)
        scene.fps = Lucy.Switch.new({ label = "Show FPS", checked = app.state:ref("settings.showFps") })
        menu(scene, "Options", { scene.fps }, {
            Lucy.Button.new({
                text = "Back",
                variant = "outline",
                onClick = function()
                    app.scenes:pop()
                end,
            }),
        })
    end,
    defaultFocus = function(scene)
        return scene.fps
    end,
})

app.scenes:goTo("Title")
```

How it fits together:

- **Opening.** B and Backspace call the game screen's `onBack` when nothing is
  open on top; see [Back](../guide/scenes.md#back). With Pause open, they pop
  it instead, and from Options they go back to Pause.
- **Focus.** Each menu starts keyboard and gamepad players on its
  `defaultFocus`. Closing a menu puts focus back where it was.
- **Keys off.** A pushed modal scene counts for `app:modalOpen()`, and the
  title screen is caught by checking `scenes.current`; see
  [While a menu is open](../guide/actions.md#while-a-menu-is-open).
- **Leaving.** Writing an empty `scenes.stack` closes every menu at once, then
  `goTo` switches the screen.
- **Icons.** The Pause button's icon needs your icon build; see
  [Icons](../guide/icons.md). Until then the button still shows its text.
