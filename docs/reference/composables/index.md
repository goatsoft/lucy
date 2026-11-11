---
title: Composables
description: State over time and behaviour shared between components. Every Lucy.use* composable.
order: 5
---

# Composables

A composable is a function named `useX` that creates refs, computeds and effects
for whatever is running now: a component's render, a scene's `build`, an
effect, or `scope:run` of a `Lucy.effectScope()`. What it creates stops with
that owner. Every composable raises an error when called without an active owner,
preventing dangling unmanaged effects.

To write your own composables, see [Share logic with composables](../../guide/composables.md).

## Built-in composables

| Composable | What it does |
|---|---|
| [`useDensity`](use-density.md) | Follows the active device density profile (`"default"`, `"touch"` or `"tv"`) |
| [`useMetric`](use-metric.md) | Computes a control height token in pixels based on density |
| [`useResponsive`](use-responsive.md) | Derives a responsive value keyed by device, mode, breakpoint or orientation |
| [`useBackHandler`](use-back-handler.md) | Intercepts back inputs (B on gamepad, Backspace on keyboard) while active |
| [`useFocusScope`](use-focus-scope.md) | Traps keyboard and gamepad focus inside a container while active |
| [`useFocusZone`](use-focus-zone.md) | A group of HUD controls nothing selects until a key steps in; B steps out |
| [`useHoldArrows`](use-hold-arrows.md) | Keeps the gamepad's selection on a control while it takes the arrows itself |
| [`useUiSound`](use-ui-sound.md) | Calls functions when components activate, toggle, open, close or select |
| [`useTable`](use-table.md) | Manages sorted rows from raw data tables and column definitions |
| [`useSort`](use-sort.md) | Sorts any arbitrary list by one or more columns with tiebreakers |
| [`useWhile`](use-while.md) | Runs a setup callback while a condition is true, cleaning up on false |
| [`useCountdown`](use-countdown.md) | Synchronized countdown of whole seconds remaining until a timestamp |
| [`useDrag`](use-drag.md) | Tracks pointer or touch drag gestures starting from a target element |
| [`useReveal`](use-reveal.md) | Types text out character by character for dialogue and notifications |
| [`useCount`](use-count.md) | Counts a number smoothly up or down with easing |
| [`useRequest`](use-request.md) | Asks the server and keeps the answer, asking again when its arguments change |

## Lifetime and ownership

Composables must be called inside an active reactive owner:

1. **Inside a component**: In `render(h)`, all refs, computeds and watchers
   created by composables are automatically bound to that component handle. When
   the component is destroyed with `handle:destroy()`, its composables are
   cleaned up automatically.
2. **Inside a scene**: In `build(scene)`, composables run in the scene's scope
   and clean up when the scene is torn down.
3. **Inside an effect or scope**: When used in custom features or client scripts
   outside components, wrap composables in an effect scope:

```luau
local scope = Lucy.effectScope()
scope:run(function()
    Lucy.useWhile(isOpen, blockInput)
end)

-- Stop all composables and effects created inside:
scope:stop()
```
