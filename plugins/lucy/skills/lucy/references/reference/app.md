<!-- Made by scripts/skills.ts from docs/reference/app.md. Edit the doc, not this file. -->
# The App

A game makes one App on the client, before it builds any UI. The App holds the
store, the themes, input, hotkeys and scenes. Components find it by themselves,
so you rarely pass it around.

```luau
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local app = Lucy.App.new({
    theme = "dark",
    baseColor = "zinc",
    primary = "violet",
    state = { player = { coins = 0 } },
})
```

For a walkthrough, see [Getting started](../index.md).

## Options

Every option is optional.

| Option | Default | What it does |
|---|---|---|
| `theme`, `baseColor`, `primary`, `themes`, `primitives`, `densities`, `density`, `styleParent` | | How the UI looks; see [Theming](theming.md#app-options) |
| `state` | `{}` | Your starting data in the [store](store.md) |
| `adaptive` | on | `false` turns scaling off; a table such as `{ max = 1.5 }` changes its numbers. See [Scaling](../architecture.md#scaling) |
| `backKeys` | `{ ButtonB, Backspace }` | The keys that go back. See [Back keys](../architecture.md#back-keys) |
| `toastPosition` | `"bottom-right"` | Where toasts show. See [Toaster](../components/toaster.md) |
| `parent` | the player's PlayerGui | Where the App's ScreenGuis go |
| `namePrefix` | `"Lucy_"` | Starts the name of every ScreenGui and folder the App makes. A second App needs its own |
| `setCurrent` | `true` | Makes this the App components use, and the one `Lucy.App.current()` returns |
| `devtools` | `true` | `false` leaves the App out of [Devtools](devtools.md) (Studio only) |
| `input`, `actions` | | For Lucy's own tests |

## What an App holds

| Field | What it is | More |
|---|---|---|
| `app.state` | The store: UI state and your game data | [The store](store.md) |
| `app.theme` | Themes, density and style rules: `app.theme:set("light")`, `app.theme:addRules(name, rules)` | [Theming](theming.md) |
| `app.scenes` | Screens, modal scenes and overlays | [Build screens with scenes](../guide/scenes.md) |
| `app.actions` | Hotkeys, in sets you switch on and off | [Hotkeys and modal input](../guide/actions.md) |
| `app.input` | The input mode and device, focus and the back keys | [Input and focus](../architecture.md#input-and-focus) |
| `app.toast` | Toasts: `app.toast("Saved")`, `app.toast.success(...)` | [Toaster](../components/toaster.md) |

## Methods

| Method | What it does |
|---|---|
| `Lucy.App.current()` | The App made with `setCurrent`, or nil. For other scripts; see [Getting started](../index.md) |
| `app:modalOpen()` | True while a modal dialog, sheet or popup is open, or a modal scene is pushed. Code that reads it runs again when it changes; see [While a menu is open](../guide/actions.md#while-a-menu-is-open) |
| `app:setTheme(name)` | Same as `app.theme:set(name)` |
| `app:setDensity(name)` | Same as `app.theme:setDensity(name)` |
| `app:handle(id)` | The component with that id, or nil |
| `app:createGui(name, options?)` | A ScreenGui on the App's theme and scaling. Options: `displayOrder`, `ignoreGuiInset` (`true`), `enabled` (`true`), `parent` |
| `app:destroy()` | Removes the App and everything it made, except ScreenGuis from `createGui`: destroy those yourself |

Scenes already give you a ScreenGui each (`scene.gui`), so use `createGui` only
for UI that lives outside scenes.
