---
title: Getting started
description: Install Lucy, create an App and build your first scene.
order: 1
---

# Getting started

Lucy is a UI and app framework for Roblox, built on
[Universal Styling](https://create.roblox.com/docs/ui/styling). It gives you
themeable components, scenes and one app state, and works with mouse, keyboard,
gamepad and touch on desktop, console, tablet and phone.

## Install

### Copy in (recommended)

Components are copied into your project as source you own. You need
[Lune](https://lune-org.github.io/docs) and a checkout of Lucy.

```sh
git clone https://github.com/goatsoft/lucy ~/Projects/Lucy
cd your-game
lune run ~/Projects/Lucy/scripts/add -- button dialog --from ~/Projects/Lucy --out src/shared/Lucy
```

- Core is always copied; dependencies come along (Dialog brings Button).
- Files you have edited are kept unless you pass `--overwrite`.
- `--list` shows every component, `--all` installs them all, `--specs` copies the tests too.

### Wally

```toml [wally.toml]
[dependencies]
Lucy = "goatsoft/lucy@0.1.0"
```

## Create the App

Create one App on the client. It owns the state, theme, input, scenes and toasts.

```luau [StarterPlayerScripts/UI.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Shared.Lucy) -- or ReplicatedStorage.Packages.Lucy

local app = Lucy.App.new({
    theme = "dark",
    baseColor = "zinc",
    primary = "violet",
    state = { player = { coins = 0 } },
})
```

Every option, and everything an App holds, is listed in [The App](reference/app.md).

Make it once, in one client script. Components you create use this App without
being told, and other scripts reach it with `Lucy.App.current()`:

```luau
local app = Lucy.App.current() -- the App, or nil if UI.client hasn't made it yet
```

`Lucy.App.current()` is nil until that script has run, so a script that may
start first should wait for it, or get the App from a ModuleScript that makes
it and returns it.

For typed code, Lucy exports its types: `Lucy.App`, `Lucy.Scene`, `Lucy.Handle`
(any component), `Lucy.Ref<T>` and more. A scene and a handle both take your own
fields, such as `scene.play`.

## Build a scene

Each scene owns one ScreenGui. Only one screen shows at a time; modals and
overlays sit above it. This title screen has a Play button that switches to
the game screen:

```luau
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
            children = {
                Lucy.Text.new({ text = "My Game", variant = "h1", align = "center" }),
                scene.play,
            },
            Parent = scene.gui,
        })
    end,
    -- What keyboard and gamepad players start on.
    defaultFocus = function(scene)
        return scene.play
    end,
})

local coins = app.state:ref("player.coins")

app.scenes:register("Game", {
    build = function(scene)
        Lucy.Text.new({
            text = function()
                return `Coins: {coins()}`
            end,
            Parent = scene.gui,
        })
    end,
})

app.scenes:goTo("Title")
```

The coins text reads app state, so it changes by itself when the game sets
`player.coins`. For more, see [Build screens with scenes](guide/scenes.md), and
the [Recipes](recipes/index.md) for whole screens to copy: a settings menu that
saves, a pause menu, a HUD and a shop.

## Drive anything from app state

```luau
app.state:set("ui.quit.open", true)           -- any component, by id
app.state:set("theme", "light")               -- switch theme
app.state:set("scenes.current", "Game")       -- navigate
app.state:subscribe("input.device", print)    -- "desktop" | "console" | "tablet" | "mobile"
```

## Dialogs and toasts

```luau
local quit = Lucy.Dialog.new({
    id = "quit",
    title = "Leave match?",
    description = "You will drop your cash.",
    actions = {
        { text = "Stay", variant = "outline" },
        { text = "Leave", variant = "destructive", onClick = leaveMatch },
    },
})
quit:open() -- or app.state:set("ui.quit.open", true)

app.toast.success("Round won", { description = "+$250" })
```

## Next

- [Build screens with scenes](guide/scenes.md): screens, a HUD, menus on top, and back
- [Add a theme](guide/themes.md): your game's colours, light and dark, and a theme of your own
- [Make your UI accessible](guide/accessibility.md): readable colours, focus, text size and motion
- [Components](components/index.md): a page for each component with its props and examples
- [Recipes](recipes/index.md): whole screens to copy: a settings menu that saves, a pause menu, a HUD and a shop
- [Stories and preview](stories.md): see your UI in Studio without pressing Play
- [Use Lucy with agents](guide/agents.md): give your coding agent Lucy's skills
- [Architecture](architecture.md): how the pieces fit together
- [Benchmarks](benchmarks.md): what mounting and updating UI costs
