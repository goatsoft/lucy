<!-- Made by scripts/skills.ts from docs/components/slider.md. Edit the doc, not this file. -->
# Slider

Picks a number between a minimum and a maximum, for settings such as volume or
camera speed. Drag the thumb or press anywhere on the track with a mouse or a
finger. With the slider focused, the arrows along it change the value on
keyboard and gamepad, one step at a time and faster while held; the other
arrows move focus as usual. It can lie flat or stand up, and grows on touch and
console.

```luau
Lucy.Slider.new({
    value = 80,
    showValue = true,
    format = function(value)
        return `{value}%`
    end,
    onValueCommit = function(value)
        settings:save("volume", value)
    end,
    Parent = settings,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `value` | number | `0` | yes | The current value |
| `min` | number | `0` | yes | The lowest value |
| `max` | number | `100` | yes | The highest value |
| `step` | number | `1` | yes | Values snap to `min` plus a whole number of steps |
| `orientation` | string | `"horizontal"` | yes | `horizontal` or `vertical` (up is more) |
| `size` | string | `"md"` | yes | `sm`, `md` or `lg`: the thumb and track thickness |
| `disabled` | boolean | `false` | yes | Greys it out and ignores input |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `showValue` | boolean | `false` | | Shows the value beside the track, or under it when vertical |
| `format` | function | | | Turns the value into the shown text; whole numbers have no point by default |
| `valueWidth` | number | `40` | | Room for the shown value beside a flat slider, in pixels |
| `length` | number | | | Length in pixels. A flat slider fills its parent's width without it; one standing up is 160 |
| `onValueChange` | function | | | Called with `(value, handle)` on every change, while dragging too |
| `onValueCommit` | function | | | Called with `(value, handle)` when a drag or a held arrow ends and the value changed |

It also takes the [props every component takes](index.md#using-a-component).

`onValueChange` follows the value as it moves, for live previews. Use
`onValueCommit` for anything costly, such as saving or telling the server: it
runs once per drag. The `select` event (for UI sounds) is sent at the same time.

## Methods

| Name | What it does |
|---|---|
| `slider:setValue(value)` | Sets the value, snapped to the step and the range |

## Examples

Keep a setting in app state, preview it live and save it when the player lets go:

```luau
local sensitivity = app.state:ref("settings.sensitivity")

Lucy.Slider.new({
    value = sensitivity,
    min = 0.1,
    max = 2,
    step = 0.1,
    showValue = true,
    onValueCommit = function(value)
        remotes.SaveSetting:FireServer("sensitivity", value)
    end,
    Parent = settings,
})
```

A small slider standing up, beside a music track list:

```luau
Lucy.Slider.new({
    value = 50,
    orientation = "vertical",
    size = "sm",
    length = 120,
    Parent = sidebar,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Slider")`.
