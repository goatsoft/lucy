---
title: Utils
description: "Plain helpers and utility classes: Lucy.Format, Lucy.Scroll, Lucy.Signal and Lucy.Maid."
order: 10
---

# Utils

Lucy includes stateless helpers and lightweight utility classes. They do not
depend on components or reactive scopes, so you can call them anywhere on the
client or the server.

| Utility | What it is |
|---|---|
| [`Lucy.Format`](#lucyformat) | Turns numbers into text with thousands separators and decimal rounding |
| [`Lucy.Scroll`](#lucyscroll) | Scrolls ancestor ScrollingFrames to reveal an object and measures scroll metrics |
| [`Lucy.Signal`](#lucysignal) | A lightweight synchronous event emitter for plain Luau objects |
| [`Lucy.Maid`](#lucymaid) | Collects instances, connections, functions and threads to clean them up together |

## Lucy.Format

`Lucy.Format` turns values into text. Its functions are plain: they take a
value and return a string, with nothing to set up or clean up.

### Format.number

```luau
Lucy.Format.number(4200)             -- "4,200"
Lucy.Format.number(-1500)            -- "-1,500"
Lucy.Format.number(1234.5678, 2)     -- "1,234.57"
Lucy.Format.number(1234567, 0, ".")  -- "1.234.567"
```

Groups a number's thousands and rounds it to `decimals` places.

| Argument | Type | Default | What it is |
|---|---|---|---|
| `n` | `number` | required | The number to format |
| `decimals` | `number?` | `0` | Decimal places to round to |
| `separator` | `string?` | `","` | Separator between groups of three digits |

Luau's `string.format` pads and rounds (`"%.1f"`, `"%05d"`), but does not add
thousands separators.

### Formatting labels in UI

Format a number inside surrounding text for player HUDs and counters:

```luau
local coins = app.state:ref("player.coins")

Lucy.Text.new({
    text = function()
        return `{Lucy.Format.number(coins())} coins`
    end,
    Parent = hud,
})
```

A [Text](../components/text.md) with a numeric `value` formats numbers with
`Lucy.Format.number` by default, and so does an animated count from
[`useCount`](composables/use-count.md) when rendered.

## Lucy.Scroll

`Lucy.Scroll` provides helpers for `ScrollingFrame`s. `InputManager` uses it
internally to keep focused objects in view during keyboard and gamepad navigation.
You can also use it directly in scenes and menus to scroll to specific items.

### Scroll.reveal

Scrolls every `ScrollingFrame` ancestor above `object` until the object is fully
visible inside each frame's viewport, or only the one you name:

```luau
Lucy.Scroll.reveal(object, margin?, only?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `object` | `GuiObject` | required | The target element to reveal |
| `margin` | `number?` | `8` | Extra padding in pixels around the element |
| `only` | `ScrollingFrame?` | every ancestor | Scroll just this frame and leave the ones around it alone |

Pass `only` when a row scrolls inside a page: a tab bar shows its picked tab in
its own scroller, and the page the bar sits in stays where the player scrolled it.

`CanvasPosition`, `AbsolutePosition` and `AbsoluteWindowSize` are in screen
pixels (after `UIScale`), so `reveal` works accurately across all screen densities
without manual scaling calculations.

```luau
-- Jump to a selected track in the Club Lucy booth queue
local function highlightTrack(trackItem: GuiObject)
    Lucy.Scroll.reveal(trackItem, 16)
end
```

### Scroll.offsetFor

A pure math function that computes the new canvas offset along one axis needed to
bring a span into view:

```luau
local newOffset = Lucy.Scroll.offsetFor(position, view, top, bottom, margin?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `position` | `number` | required | Current canvas scroll position |
| `view` | `number` | required | Visible window size along the axis |
| `top` | `number` | required | Starting coordinate of the span in canvas space |
| `bottom` | `number` | required | Ending coordinate of the span in canvas space |
| `margin` | `number?` | `0` | Extra padding around the span |

Returns `position` unchanged if the span is already within the visible view. If
the span is taller than `view`, it returns the offset that aligns the top edge.

### Scroll.scaleOf

Returns the combined scale factor of all `UIScale` objects above `object`:

```luau
local scale = Lucy.Scroll.scaleOf(object)
```

Use `scaleOf` to convert measured screen coordinates (`AbsoluteSize`) back into
the unscaled layout offsets used by `UDim2`.

## Lucy.Signal

`Lucy.Signal` is a tiny synchronous event system for plain Luau objects where an
engine `RBXScriptSignal` is not available. Handlers run synchronously in
connection order; an error in one handler reports a warning and does not prevent
other handlers from running.

### Methods

| Method | Returns | What it does |
|---|---|---|
| `Signal.new()` | `Signal` | Creates a new signal instance |
| `signal:Connect(fn)` | `Connection` | Subscribes a handler function |
| `signal:Once(fn)` | `Connection` | Subscribes a handler that disconnects itself after running once |
| `signal:Fire(...)` | `()` | Calls every active handler synchronously with the given arguments |
| `signal:DisconnectAll()` | `()` | Disconnects all active handlers |

A `Connection` object provides:

- `conn.Connected`: `boolean` indicating if the connection is still active.
- `conn:Disconnect()`: Disconnects this handler from the signal.

### Example: DJ booth events

Use signals for decoupled client-side events between game features and UI:

```luau
local onTrackChanged = Lucy.Signal.new()

local conn = onTrackChanged:Connect(function(trackName: string, bpm: number)
    print(`Now playing {trackName} at {bpm} BPM`)
end)

-- Fire when the track changes
onTrackChanged:Fire("Neon Nights", 124)

-- Clean up
conn:Disconnect()
```

## Lucy.Maid

`Lucy.Maid` collects tasks and objects that require cleanup and tears them down
together in one call. Tasks are cleaned up in reverse order (last in, first out),
ensuring dependents are cleaned up before their dependencies.

### Supported cleanup types

| Type | How Maid cleans it |
|---|---|
| `Instance` | Calls `item:Destroy()` |
| `RBXScriptConnection` | Calls `item:Disconnect()` |
| `Lucy.Signal.Connection` | Calls `item:Disconnect()` |
| `function` | Invokes `item()` |
| `thread` | Cancels via `task.cancel(thread)` if still alive |
| `table` | Calls `item:Destroy()`, `item:destroy()`, or `item:Disconnect()` |

### Methods

| Method | What it does |
|---|---|
| `Maid.new()` | Creates an empty Maid |
| `maid:give(item)` | Adds `item` to the cleanup list and returns `item` |
| `maid:clean()` | Cleans up every item in reverse order and clears the list |
| `maid:destroy()` | Alias for `maid:clean()` |
| `maid:Destroy()` | Alias for `maid:clean()` |

### Example: cleaning up floor effects

```luau
local floorMaid = Lucy.Maid.new()

-- Give parts, connections, threads and functions to the maid
floorMaid:give(danceFloorLightPart)
floorMaid:give(sound.Ended:Connect(onTrackFinished))
floorMaid:give(task.spawn(pulseFloorBeats))
floorMaid:give(function()
    print("Dance floor effects torn down")
end)

-- When the player leaves the dance floor, clean everything in one call:
floorMaid:clean()
```
