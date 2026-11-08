---
title: useDrag
description: Follows a mouse or touch drag starting from a target GUI element.
order: 11
---

# useDrag

`Lucy.useDrag` tracks dragging gestures initiated by a press on `target` (using
either mouse button 1 or a single touch finger). Once the drag starts, moving
anywhere on the screen continues the drag, and releasing ends it. All position
and delta values are reported in screen pixels.

## Usage

```luau
local drag = Lucy.useDrag(target, options)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `target` | `GuiObject | Ref<GuiObject?>` | required | The boundary element initiating the drag |
| `options` | `table` | required | Gesture configuration and callbacks |

### Options

| Option | Type | What it does |
|---|---|---|
| `onStart(point)` | `(point: Vector2) -> ()` | Called on initial press with screen position |
| `onMove(delta, point)` | `(delta: Vector2, point: Vector2) -> ()` | Called on pointer movement with total delta and current position |
| `onEnd(delta)` | `(delta: Vector2) -> ()` | Called when the pointer is released with total delta |
| `disabled` | `MaybeRef<boolean>` | When true, new drags cannot start and active drags are ended |

### Returns

| Name | Type | What it is |
|---|---|---|
| `dragging()` | `() -> boolean` | `true` while the drag gesture is active |
| `delta()` | `() -> Vector2` | Total distance moved from initial press (`Vector2.zero` when inactive) |
| `cancel()` | `() -> ()` | Cancels the active drag immediately and invokes `onEnd` |

## Example: spinning the Club Lucy avatar model

In the wardrobe, players can drag horizontally across the preview viewport to
spin their dancer avatar:

```luau
local function AvatarTurntable(h)
    local angle = Lucy.ref(0)
    local startAngle = 0
    local viewport = Lucy.ref(nil)

    Lucy.useDrag(viewport, {
        onStart = function()
            startAngle = angle()
        end,
        onMove = function(delta)
            angle(startAngle - delta.X * 0.015)
        end,
    })

    return Lucy.new "ViewportFrame" {
        [Lucy.ref] = viewport,
        Size = UDim2.fromOffset(240, 320),
    }
end
```
