---
title: useCount
description: Counts a number smoothly up or down to a target value with easing.
order: 13
---

# useCount

`Lucy.useCount` animates a number smoothly towards `value` whenever `value`
changes. It starts from `from` (`0` by default) and eases out towards the new
target.

## Usage

```luau
local counter = Lucy.useCount(value, options?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `value` | `MaybeRef<number>` | required | Target number to count to |
| `options` | `table?` | `{}` | Timing and starting value |

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `seconds` | `number` | `0.8` | How long the count takes, in seconds |
| `from` | `number` | `0` | Starting value on mount |

### Returns

| Name | Type | What it is |
|---|---|---|
| `value()` | `() -> number` | Current animated number (unrounded) |
| `counting()` | `() -> boolean` | `true` while counting |
| `skip()` | `() -> ()` | Jumps straight to the target value |
| `done` | `Lucy.Signal` | Fires when the count reaches the target |

Pass `counter.value()` through
[`Lucy.Format.number`](../utils.md#formatnumber) to round it and add commas.

## Example: coin reward

Count up won coins and play a chime when the count finishes:

```luau
local coins = app.state:ref("player.coins")
local displayedCoins = Lucy.useCount(coins, { seconds = 1, from = 0 })

displayedCoins.done:Connect(function()
    sounds.coinChime:Play()
end)

Lucy.new "TextLabel" {
    Text = function()
        return `{Lucy.Format.number(displayedCoins.value())} coins`
    end,
    Parent = hud,
}
```

[Text](../../components/text.md) has this built in via `value` and `count`:
`Lucy.Text.new({ value = coins, count = true })`.
