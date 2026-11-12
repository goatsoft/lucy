<!-- Made by scripts/skills.ts from docs/reference/utils.md. Edit the doc, not this file. -->
# Utils

Plain helpers and utility classes that work anywhere on the client or server,
without components or reactive scopes.

| Utility | What it does |
|---|---|
| [`Lucy.Format`](#lucyformat) | Formats numbers with thousands separators and decimal rounding |
| [`Lucy.Scroll`](#lucyscroll) | Scrolls ancestor ScrollingFrames to show an object and reads combined UIScale |
| [`Lucy.Signal`](#lucysignal) | Synchronous event emitter for plain Luau objects |
| [`Lucy.Maid`](#lucymaid) | Collects instances, connections, functions and threads to clean them up in one call |

## Lucy.Format

`Lucy.Format` turns values into strings, with nothing to set up or clean up.

### Format.number

```luau
Lucy.Format.number(4200)             -- "4,200"
Lucy.Format.number(-1500)            -- "-1,500"
Lucy.Format.number(1234.5678, 2)     -- "1,234.57"
Lucy.Format.number(1234567, 0, ".")  -- "1.234.567"
```

Groups thousands and rounds to `decimals` places.

| Argument | Type | Default | What it does |
|---|---|---|---|
| `n` | `number` | required | Number to format |
| `decimals` | `number?` | `0` | Decimal places to round to |
| `separator` | `string?` | `","` | Separator between groups of three digits |

Luau's `string.format` pads and rounds (`"%.1f"`, `"%05d"`), without adding
thousands separators.

### Formatting labels in UI

Format numbers inside labels and counters:

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
`Lucy.Format.number` by default, and [`useCount`](composables/use-count.md)
follows the same formatting.

## Lucy.Scroll

`Lucy.Scroll` provides helpers for `ScrollingFrame`s. `InputManager` uses it to
keep focused items in view on keyboard and gamepad, and you can call it directly
in your own menus.

### Scroll.reveal

Scrolls every `ScrollingFrame` ancestor above `object` until `object` fits inside
each viewport, or only the single frame you pass in `only`:

```luau
Lucy.Scroll.reveal(object, margin?, only?)
```

| Argument | Type | Default | What it does |
|---|---|---|---|
| `object` | `GuiObject` | required | Element to scroll into view |
| `margin` | `number?` | `8` | Extra padding in pixels around `object` |
| `only` | `ScrollingFrame?` | every ancestor | Scroll only this frame and leave outer scrollers alone |

Pass `only` when one scroller sits inside another: a tab bar scrolls its active
tab into view inside its own strip without scrolling the whole page.

`CanvasPosition`, `AbsolutePosition` and `AbsoluteWindowSize` are measured in
screen pixels (after `UIScale`), so `reveal` works across densities without
extra maths.

```luau
-- Jump to a picked track in the booth queue
local function highlightTrack(trackItem: GuiObject)
    Lucy.Scroll.reveal(trackItem, 16)
end
```

### Scroll.offsetFor

Computes the new canvas offset along one axis needed to bring a span into view:

```luau
local newOffset = Lucy.Scroll.offsetFor(position, view, top, bottom, margin?)
```

| Argument | Type | Default | What it does |
|---|---|---|---|
| `position` | `number` | required | Current canvas scroll position |
| `view` | `number` | required | Visible window size along the axis |
| `top` | `number` | required | Start of the span in canvas space |
| `bottom` | `number` | required | End of the span in canvas space |
| `margin` | `number?` | `0` | Extra padding around the span |

Returns `position` unchanged when the span is already in view. When the span is
taller than `view`, it aligns the top edge.

### Scroll.scaleOf

Returns the combined scale factor of every `UIScale` above `object`:

```luau
local scale = Lucy.Scroll.scaleOf(object)
```

Use `scaleOf` to convert measured screen pixels (`AbsoluteSize`) back into
unscaled layout offsets for `UDim2`.

## Lucy.Signal

`Lucy.Signal` is a synchronous event for plain Luau objects when a Roblox
`RBXScriptSignal` is not available. Handlers run in connection order; an error in
one logs a warning and does not stop the rest.

### Methods

| Method | Returns | What it does |
|---|---|---|
| `Signal.new()` | `Signal` | Creates a signal |
| `signal:Connect(fn)` | `Connection` | Registers a handler |
| `signal:Once(fn)` | `Connection` | Registers a handler that disconnects after firing once |
| `signal:Fire(...)` | `()` | Calls every active handler synchronously with the arguments |
| `signal:DisconnectAll()` | `()` | Disconnects all active handlers |

A `Connection` provides `conn.Connected` (boolean) and `conn:Disconnect()`.

### Example: booth events

Use signals for plain Luau events between game systems and UI:

```luau
local onTrackChanged = Lucy.Signal.new()

local conn = onTrackChanged:Connect(function(trackName: string, bpm: number)
    print(`Now playing {trackName} at {bpm} BPM`)
end)

onTrackChanged:Fire("Neon Nights", 124)

conn:Disconnect()
```

## Lucy.Maid

`Lucy.Maid` collects cleanup tasks and tears them down together in reverse order
(last in, first out), so later resources clean up before the things they depend on.

### Supported cleanup types

| Type | How Maid cleans it |
|---|---|
| `Instance` | Calls `item:Destroy()` |
| `RBXScriptConnection` | Calls `item:Disconnect()` |
| `Lucy.Signal.Connection` | Calls `item:Disconnect()` |
| `function` | Calls `item()` |
| `thread` | Cancels via `task.cancel(thread)` if still alive |
| `table` | Calls `item:Destroy()`, `item:destroy()`, or `item:Disconnect()` |

### Methods

| Method | What it does |
|---|---|
| `Maid.new()` | Creates an empty Maid |
| `maid:give(item)` | Adds `item` to the cleanup list and returns it |
| `maid:clean()` | Cleans every item in reverse order and clears the list |
| `maid:destroy()` | Alias for `maid:clean()` |
| `maid:Destroy()` | Alias for `maid:clean()` |

### Example: cleaning up floor effects

```luau
local floorMaid = Lucy.Maid.new()

floorMaid:give(danceFloorLightPart)
floorMaid:give(sound.Ended:Connect(onTrackFinished))
floorMaid:give(task.spawn(pulseFloorBeats))
floorMaid:give(function()
    print("Dance floor effects torn down")
end)

-- When the player leaves the floor, clean everything in one call:
floorMaid:clean()
```
