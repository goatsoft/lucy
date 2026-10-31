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

Which to use for a menu:

- A **modal scene** for a full menu with its own layout, such as pause or
  settings, that stays built between visits.
- A [Sheet](../components/sheet.md) for a panel that slides in from the side,
  such as an inventory, with the game still showing.
- A [Dialog](../components/dialog.md) for a short question or a small window,
  such as "Leave the game?".

An app doesn't need a screen at all: a game with only a HUD shows its overlays
with `show`.

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
| `defaultFocus(scene)` | what keyboard and gamepad players start on: an Instance or a component. Optional: without it, the first thing that can take focus. Overlays ignore it |
| `onBack(scene)` | B or Backspace on a screen, when nothing is open on top |
| `keepAlive` | `true` (the default) keeps the UI when the scene hides; `false` destroys it and builds it again next time |
| `ignoreGuiInset` | `true` (the default) draws under Roblox's top bar; see [Safe area](#safe-area) |

`scene` is a table you can keep your own parts on, like `scene.play` above. It
also has `scene.gui`, `scene.app`, `scene.params` and `scene.maid`.
`scene.maid:give(thing)` cleans up `thing` when the scene is destroyed: an
Instance, a connection, a function to call, or anything with a `Destroy` or
`destroy` method.

`build` runs in the scene's own scope, so [composables](../reference/composables.md)
work in it, and the components, bindings and watchers it makes last until the
scene is destroyed.

If `build`, `enter` or `exit` fails, Lucy warns with the scene's name and keeps
showing the rest. A scene that failed to build is built again the next time it
shows.

## Move between screens

```luau
app.scenes:goTo("Game")
app.scenes:goTo("Results", { score = 1200, place = 2 })
```

The old screen hides and the new one shows. Calling `goTo` on the screen already
showing, with new params, runs its `exit` and `enter` again. `goTo` leaves open
modals open; to go back to the title from a pause menu, close them first with
`app.state:set("scenes.stack", {})`.

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

Pushing a modal that's already open moves it to the top. `pop` returns the name
of the scene it closed, or nil when none was open.

A modal scene stops clicks reaching the scenes below it, but draws no dimmed
backdrop and doesn't close when the player clicks outside it. Add your own
backdrop if you want one, such as a full screen Frame with a `$Background` rule
at half transparency.

A pushed modal scene counts for `app:modalOpen()`, like an open dialog.

## Safe area

Scenes draw over the whole screen by default, under Roblox's top bar and a
phone's notch. That suits backgrounds. For a HUD, keep it clear of them:

```luau
app.scenes:register("Hud", {
    layer = "overlay",
    ignoreGuiInset = false, -- start below Roblox's top bar
    build = function(scene)
        scene.gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- and clear of the notch
        -- ...
    end,
})
```

`Enum.ScreenInsets.DeviceSafeInsets` keeps clear of the notch and rounded
corners only. Lucy also scales every scene for the device; see
[Scaling](../architecture.md#scaling).

## Back

`app.scenes:back()` closes the top modal, or, with none open, calls the current
screen's `onBack`. Lucy calls it for the [back keys](../architecture.md#back-keys),
B on a gamepad and Backspace on a keyboard, when nothing else, such as an open
select, takes them first:

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
| `scenes.stack` | the names of the open modals, top last; nil until the first `push` |
| `scenes.visible` | `{ [name] = true }` for each overlay shown |

Writing them navigates too: `app.state:set("scenes.current", "Game")` is the same
as `goTo("Game")`. `app.scenes:current()`, `isVisible(name)` and `get(name)` (the
scene table, once built) read them directly, and `app.scenes.Changed` fires with
the new and old screen.
