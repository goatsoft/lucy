---
title: Composables
description: Every composable Lucy comes with, what each one takes and returns, and when to use it.
order: 2
---

# Composables

A composable is a function named `useX` that creates refs, computeds and effects
for whatever is running now: a component's render, an effect, or `scope:run` of a
`Lucy.effectScope()`. What it creates stops with that owner. Every composable
here raises an error when there is no owner, since nothing would ever stop it.

To write your own, see [Share logic with composables](../guide/composables.md).

| Composable | What it does |
|---|---|
| [`useDensity`](#usedensity) | The device's density: `"default"`, `"touch"` or `"tv"` |
| [`useMetric`](#usemetric) | A control size in pixels, following density |
| [`useResponsive`](#useresponsive) | A value that changes with the device, such as a gap |
| [`useBackHandler`](#usebackhandler) | Escape or ButtonB calls your function while active |
| [`useFocusScope`](#usefocusscope) | Keeps keyboard and gamepad focus inside a frame while active |
| [`useUiSound`](#useuisound) | Calls your functions when components are clicked, toggled, opened or closed |

## useDensity

```lua
local density = Lucy.useDensity(app) -- "default", "touch" or "tv"
```

Returns a getter that follows the theme's density. Every caller in an app shares
one, so it costs nothing to ask for.

## useMetric

```lua
local height = Lucy.useMetric(app, "ControlMd")
```

Returns a computed with the pixel height of a control token (`ControlSm`,
`ControlMd`, `ControlLg` or `ControlIcon`) in the current density.

## useResponsive

```lua
local gap = Lucy.useResponsive(app, { touch = 16, default = 8 })
```

Returns a getter for a responsive value, picked for the player's device and input.
A plain value comes back as a getter too, so you can bind either the same way. See
[Responsive values](../components/index.md#responsive-values) for the keys it takes.

## useBackHandler

```lua
Lucy.useBackHandler(app, isOpen, function()
    isOpen(false)
    return true -- handled; stop here
end)
```

While `active` (a ref, getter or plain value) is true, Escape and ButtonB call
the function. Return `true` when you handled the press, so nothing under it
gets it too. The newest handler goes first.

## useFocusScope

```lua
Lucy.useFocusScope(app, isOpen, { root = panel, defaultFocus = playButton })
```

While `active` is true, keyboard and gamepad focus stays inside `root`, starting
on `defaultFocus` (an Instance, or a function returning one).

## useUiSound

```lua
Lucy.useUiSound(app, {
    activate = function(handle) playClick() end,
    toggle = function(handle, checked) playSwitch(checked) end,
    open = playWhoosh,
    close = playWhoosh,
})
```

Lucy plays no audio. Components report what the player did, and this calls your
functions so the game can play its own sounds. Each function gets the component's
handle, and for some events a value:

| Event | When | Value |
|---|---|---|
| `activate` | A Button or Pressable is clicked | |
| `toggle` | The player turns a Switch or Checkbox on or off | The new checked state |
| `open` | A Dialog opens | |
| `close` | A Dialog closes | |

Which map a component uses:

- **Its own owners first.** Lucy looks from the component up through the scopes
  it was made in, and the first map that names the event wins. Call it in a
  scene to cover that scene; call it again in part of the scene to change a few
  events there.
- **`false` silences an event**, such as `{ activate = false }` for buttons that
  are pressed on every beat.
- **Components made with no owner**, by plain script code, use the newest map
  from a top level `Lucy.effectScope()`.
- **`sound = false`** in one component's props silences that component.

A function that errors is reported in the output and never breaks the click.

Your own components report events the same way, with `h:emit(event, value)`.
