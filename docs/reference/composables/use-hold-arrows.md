---
title: useHoldArrows
description: Keeps the gamepad's selection on a control while it takes the arrows itself, such as a grabbed clip.
order: 7
---

# useHoldArrows

`Lucy.useHoldArrows` keeps the gamepad's selection on `target` while `active` is
true, so the D-pad and the left stick reach the component's `nudge` method
instead of moving the selection to the next control. Use it for a control that
the arrows change while it is in a mode: a timeline clip the player has grabbed
and is sliding, a value being edited.

Arrows go to the nearest component around the focus with a `nudge(dx, dy,
count)` method that returns true (see [Architecture](../../architecture.md#input-and-focus)).
The engine moves gamepad selection on the same press, though, unless the control
tells it to stay. That is what this composable does: while active, each of the
target's `NextSelection*` points at the target itself; after, they are cleared.

Games call this rather than setting `NextSelection*` themselves.

## Usage

```luau
Lucy.useHoldArrows(target, active)
```

| Argument | Type | What it is |
|---|---|---|
| `target` | `MaybeRef<GuiObject?>` | The control that takes the arrows |
| `active` | `MaybeRef<boolean>` | While true, the selection stays on it |

## Example: sliding a grabbed clip

A clip is a Pressable. A grabs it, the arrows then slide it a beat at a time,
and A again puts it down:

```luau
local clip = Lucy.Pressable.new({
    onClick = function()
        grabbed(not grabbed())
    end,
})

function clip.nudge(_h, dx: number, dy: number): boolean
    if not grabbed() then
        return false -- not grabbed: the arrows move focus as usual
    end
    slide(dx)
    return true
end

Lucy.useHoldArrows(clip.Instance, grabbed)
```
