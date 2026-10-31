<!-- Made by scripts/skills.ts from docs/guide/scenes.md. Edit the doc, not this file. -->
# Build screens with scenes

A scene is one part of your game's UI with its own ScreenGui: the title screen,
the HUD, the pause menu. Lucy shows and hides them for you, keeps their order
right and moves keyboard and gamepad focus into the one on top, so menus never
fight over input.

## Three kinds

| Layer | Shown | For |
|---|---|---|
| `screen` | exactly one at a time | Title, Lobby, Game |
| `overlay` | any number, alongside the screen | HUD, chat, minimap |
| `modal` | stacked on top, newest above | Pause, Settings, Shop |

Dialogs, selects, sheets and toasts float above every scene on their own layer;
you don't make scenes for them.

## Register a scene

```luau
app.scenes:register("Title", {
    layer = "screen",
    build = function(scene)
        scene.play = Lucy.Button.new({
            text = "Play",
            onClick = function()
                app.scenes:goTo("Game")
            end,
            Parent = scene.gui,
        })
    end,
    defaultFocus = function(scene)
        return scene.play
    end,
})
```

| Field | What it does |
|---|---|
| `layer` | `"screen"` (the default), `"overlay"` or `"modal"` |
| `build(scene)` | makes the UI once, the first time the scene shows; parent it to `scene.gui` |
| `enter(scene, params)` | runs every time the scene shows, with what you passed to `goTo`, `push` or `show` |
| `exit(scene)` | runs every time it hides |
| `defaultFocus(scene)` | what keyboard and gamepad players start on; give every screen and modal one |
| `onBack(scene)` | Escape or B on a screen, when nothing is open on top |
| `keepAlive` | `true` (the default) keeps the UI when the scene hides; `false` destroys it and builds it again next time |

`scene` is a table you can keep your own parts on, like `scene.play` above. It
also has `scene.gui`, `scene.app`, `scene.params` and `scene.maid` (give it
anything to clean up when the scene is destroyed).

## Move between screens

```luau
app.scenes:goTo("Game")
app.scenes:goTo("Results", { score = 1200, place = 2 })
```

The old screen hides and the new one shows. Calling `goTo` on the screen already
showing, with new params, runs its `exit` and `enter` again.

## Show a HUD

Overlays show next to whatever screen is up:

```luau
local coins = app.state:ref("coins")

app.scenes:register("Hud", {
    layer = "overlay",
    build = function(scene)
        Lucy.Text.new({
            text = function()
                return `Coins: {coins()}`
            end,
            Parent = scene.gui,
        })
    end,
})

app.scenes:show("Hud")
app.scenes:hide("Hud")
```

## Open a menu on top

Modals stack. The newest is on top and takes keyboard and gamepad focus; the
scenes under it stop taking input until it closes:

```luau
app.scenes:push("Pause")
app.scenes:push("Settings") -- over Pause
app.scenes:pop()            -- back to Pause
```

Pushing a modal that's already open moves it to the top.

## Back

`app.scenes:back()` closes the top modal, or, with none open, calls the current
screen's `onBack`. Lucy calls it for Escape and the gamepad's B button when
nothing else, such as an open select, takes them first:

```luau
app.scenes:register("Game", {
    build = buildGame,
    onBack = function()
        app.scenes:push("Pause")
    end,
})
```

To stop gameplay keys and the character while a menu is open, see
[Hotkeys and modal input](actions.md).

## From app state

Scenes are app state, so you can read and follow them like anything else:

| Key | Holds |
|---|---|
| `scenes.current` | the screen showing |
| `scenes.stack` | the open modals, top last |
| `scenes.visible` | `{ [name] = true }` for each overlay shown |

Writing them navigates too: `app.state:set("scenes.current", "Game")` is the same
as `goTo("Game")`. `app.scenes:current()`, `isVisible(name)` and `get(name)` (the
scene table, once built) read them directly, and `app.scenes.Changed` fires with
the new and old screen.
