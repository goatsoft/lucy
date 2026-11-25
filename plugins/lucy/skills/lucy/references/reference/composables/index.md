<!-- Made by scripts/skills.ts from docs/reference/composables/index.md. Edit the doc, not this file. -->
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
| [`useFit`](use-fit.md) | Scales something down to the width its parent has, so words and rows never run out of a card |
| [`useHasVisibleChild`](use-has-visible-child.md) | Whether any child of a frame has `Visible` on, so a slot whose contents all hide can drop out of its layout |
| [`useUiSound`](use-ui-sound.md) | Runs callbacks when components activate, toggle, open, close or select |
| [`useTable`](use-table.md) | Manages sorted rows from raw tables and column definitions |
| [`useSort`](use-sort.md) | Sorts a list by one or more columns with tiebreakers |
| [`useWhile`](use-while.md) | Runs a setup callback while a condition holds, cleaning up when it turns false |
| [`useCountdown`](use-countdown.md) | Synchronised countdown of whole seconds remaining until a timestamp |
| [`useDrag`](use-drag.md) | Follows mouse or touch drags starting from a control |
| [`useReveal`](use-reveal.md) | Types text out character by character for dialogue and notices |
| [`useCount`](use-count.md) | Animates a number smoothly toward a target value |
| [`useRequest`](use-request.md) | Calls the server, keeps the answer and requests again when inputs change |
| [`useIntersect`](use-intersect.md) | Whether something has been scrolled near yet, for building it only then |
| [`useDelayGroup`](use-delay-group.md) | Shares an open delay and warm skip window across tooltips |
| [`useDismiss`](use-dismiss.md) | Closes floating content on Back or on a press outside it |
| [`useFocus`](use-focus.md) | Tracks whether keyboard or gamepad focus is on a control or inside it |
| [`useHover`](use-hover.md) | Tracks pointer hover over a target with open and close delays |
| [`usePress`](use-press.md) | Tracks hold, long-press or toggle presses on a control |
| [`useProximity`](use-proximity.md) | Tracks whether the local character is within a stud distance of a world target |

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
