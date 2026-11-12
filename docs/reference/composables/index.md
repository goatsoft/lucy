---
title: Composables
description: State over time and behaviour shared between components. Every Lucy.use* composable.
order: 7
---

# Composables

A composable is a function named `useX` that creates refs, computeds and effects
for whatever is running now: a component's render, a scene's `build`, an
effect, or `scope:run` on a `Lucy.effectScope()`. Anything it creates stops when
that owner stops. Calling a composable without an active owner throws an error.

To write your own composables, see [Share logic with composables](../../guide/composables.md).

## Built in composables

| Composable | What it does |
|---|---|
| [`useDensity`](use-density.md) | Follows the active density profile (`"default"`, `"touch"` or `"tv"`) |
| [`useMetric`](use-metric.md) | Returns a control height in pixels for the current density |
| [`useResponsive`](use-responsive.md) | Picks a value by device, input mode, breakpoint or orientation |
| [`useBackHandler`](use-back-handler.md) | Handles back inputs (B on gamepad, Backspace on keyboard) while active |
| [`useFocusScope`](use-focus-scope.md) | Keeps keyboard and gamepad focus inside a frame while active |
| [`useFocusZone`](use-focus-zone.md) | A group of HUD controls skipped by focus until the player steps in; B steps out |
| [`useHoldArrows`](use-hold-arrows.md) | Holds gamepad selection on a control while it handles arrow keys itself |
| [`useSize`](use-size.md) | Tracks an object's size in layout units, for layouts that react to available space |
| [`useUiSound`](use-ui-sound.md) | Runs callbacks when components activate, toggle, open, close or select |
| [`useTable`](use-table.md) | Manages sorted rows from raw tables and column definitions |
| [`useSort`](use-sort.md) | Sorts a list by one or more columns with tiebreakers |
| [`useWhile`](use-while.md) | Runs a setup callback while a condition holds, cleaning up when it turns false |
| [`useCountdown`](use-countdown.md) | Synchronised countdown of whole seconds remaining until a timestamp |
| [`useDrag`](use-drag.md) | Follows mouse or touch drags starting from a control |
| [`useReveal`](use-reveal.md) | Types text out character by character for dialogue and notices |
| [`useCount`](use-count.md) | Animates a number smoothly toward a target value |
| [`useRequest`](use-request.md) | Calls the server, keeps the answer and requests again when inputs change |

## Lifetime and ownership

Call composables inside an active reactive owner:

1. **In a component**: Inside `render(h)`, composables attach to that handle
   and stop when `handle:destroy()` runs.
2. **In a scene**: Inside `build(scene)`, composables attach to the scene and
   stop when the scene tears down.
3. **In scripts or effects**: Outside components and scenes, wrap calls in an
   effect scope:

```luau
local scope = Lucy.effectScope()
scope:run(function()
    Lucy.useWhile(isOpen, blockInput)
end)

-- Stop everything created inside the scope:
scope:stop()
```
