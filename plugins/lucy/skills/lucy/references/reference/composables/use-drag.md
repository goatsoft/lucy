<!-- Made by scripts/skills.ts from docs/reference/composables/use-drag.md. Edit the doc, not this file. -->
# useDrag

`Lucy.useDrag` tracks dragging gestures that start with a press on `target`
(left mouse button or one touch finger). Once a drag starts, moving anywhere on
screen continues it, and releasing ends it. Positions and deltas are in screen
pixels.

## Usage

```luau
local drag = Lucy.useDrag(target, options)
```

| Argument | Type | Default | What it does |
|---|---|---|---|
| `target` | `GuiObject | Ref<GuiObject?>` | required | Element that starts the drag when pressed |
| `options` | `table` | required | Callbacks and options |

### Options

| Option | Type | What it does |
|---|---|---|
| `onStart(point)` | `(point: Vector2) -> ()` | Called on press with the screen position |
| `onMove(delta, point)` | `(delta: Vector2, point: Vector2) -> ()` | Called as the pointer moves, with total delta and current position |
| `onEnd(delta)` | `(delta: Vector2) -> ()` | Called when the pointer releases, with the total delta |
| `disabled` | `MaybeRef<boolean>` | Stops new drags starting and ends any active drag |

### Returns

| Name | Type | What it is |
|---|---|---|
| `dragging()` | `() -> boolean` | `true` while dragging |
| `delta()` | `() -> Vector2` | Total movement from the press (`Vector2.zero` when idle) |
| `cancel()` | `() -> ()` | Stops the current drag and calls `onEnd` |

## Example: spin an avatar preview

Drag across the wardrobe viewport to spin the dancer model:

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
        [Lucy.instance] = viewport,
        Size = UDim2.fromOffset(240, 320),
    }
end
```
