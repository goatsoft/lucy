---
title: Devtools
description: Look at a running UI in Studio, and press, set and focus things the way a player would, from the command bar or a coding agent.
order: 4
---

# Devtools

`Lucy.Devtools` shows what your UI is doing while the game runs in Studio:
every component with its state, what is focused, which dialogs are open and
which hotkeys are on. It can also act like a player: press a button, pick a
tab, move focus. Use it from the command bar, or let a coding agent use it to
check its own work.

```luau
local Devtools = require(game.ReplicatedStorage.Packages.Lucy).Devtools

Devtools.tree()                       -- every component on screen
Devtools.press("shop-open")           -- click the shop button
Devtools.state("player.coins")        -- 500
```

Devtools works in Studio only. In Play, run it on the client: in the command
bar, switch the view to the client first. Live games have no Devtools.

## Finding your app

Code you run from the command bar, or that an agent runs, gets its own copy of
Lucy and cannot see the App your game made. So in Studio every App leaves a
small hidden link that Devtools calls through. You never set it up.

Every function takes an options table last. Most games have one App and never
need it. When several run, Devtools uses the one made with `setCurrent` (the
default), or you name one by its `namePrefix`:

```luau
Devtools.tree({ app = "Lucy_" })
```

`Devtools.apps()` lists what is running. To leave an App out of Devtools, make
it with `Lucy.App.new({ devtools = false })`.

## Reading

| Function | Returns |
|---|---|
| `Devtools.apps()` | Each running app: `name`, `theme`, `density`, `mode`, `device`, `scene`, `stack`, `modalOpen` and how many components it has |
| `Devtools.tree(options?)` | The components as a tree, in reading order (see below). `root = id` starts from one component; `shownOnly = true` leaves out hidden ones |
| `Devtools.state(path?, options?)` | A copy of the [store](store.md), or of one path in it |
| `Devtools.focus(id?, options?)` | What is focused, the components around it, the input `mode` and whether the player is `navigating` with keys or a gamepad |
| `Devtools.overlays(options?)` | The open dialogs, sheets and popups, oldest first, each with `id`, `kind` and `modal`, and `modalOpen` |
| `Devtools.actions(options?)` | Every action set: whether it is `enabled`, its `priority`, and each action's key names |

Each node in the tree has:

| Field | What it is |
|---|---|
| `id` | The component's id, the one `press`, `focus` and `ui.<id>` use |
| `kind` | `button`, `panel`, `slider` and so on |
| `text` | The first text it shows itself, not counting the components inside it |
| `state` | Its state keys and values |
| `flags` | Which of `disabled`, `checked`, `selected`, `open`, `focused` and `focus-visible` it has |
| `shown` | Whether it is on screen (it and every parent visible) |
| `size`, `position` | In pixels |
| `gui` | The ScreenGui it is in |
| `children` | The components inside it |

Everything comes back as plain values: an Instance is its full name, a colour
or a size is its text, and functions are left out.

Give an `id` to anything you want to find easily. Components without one get
an id like `button-3`, which changes when the UI is built in another order.

## Acting

| Function | What it does |
|---|---|
| `Devtools.press(id, value?, options?)` | Clicks the component. With a value, picks it in a toggle group, tabs, select or radio group, sets a slider or number field, or opens that section of an accordion |
| `Devtools.set(path, value, options?)` | Writes the store, as game code would |
| `Devtools.focus(id, options?)` | Moves focus to the component, or to the first part of it that can take focus, and switches to keyboard navigation so the focus ring shows |

These go through the same code as the player's input, so `onClick` runs,
sounds play and a disabled button stays put: `press` returns `ok = false` with
a reason instead.

```luau
Devtools.press("shop-open")
Devtools.press("theme", "light")      -- a toggle group
Devtools.press("volume", 40)          -- a slider
Devtools.set("player.coins", 10)
Devtools.press("buy-sword")           -- { ok = false, reason = '"buy-sword" is disabled' }
```

Hotkeys go through their keys as usual; Devtools does not press actions.

## Previewing a story

`Devtools.preview(story)` shows a [story](../stories.md) in edit mode, the same
as `Lucy.Preview.show`, for a screenshot without pressing Play.

## When something goes wrong

- **"no Lucy app is running here":** the game is not running, or the code ran
  on the server or in edit mode. Press Play and run it on the client.
- **"several apps run":** name one with `{ app = name }`; the error lists them.
- **"no component":** check the id with `Devtools.tree()`.
- **"did not answer":** the app is busy or gone. Devtools waits 3 seconds
  (`Devtools.timeout`).
