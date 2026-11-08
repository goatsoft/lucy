<!-- Made by scripts/skills.ts from docs/reference/composables/use-count.md. Edit the doc, not this file. -->
# useCount

`Lucy.useCount` animates a numeric value smoothly towards a target number,
updating whenever the target value changes. It starts from `from` (defaulting to
0) and applies ease-out timing so large score increases or coin gains feel punchy
without dragging on.

## Usage

```luau
local counter = Lucy.useCount(value, options?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `value` | `MaybeRef<number>` | required | Target number to count towards |
| `options` | `table?` | `{}` | Timing and starting options (see below) |

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `seconds` | `number` | `0.8` | Total duration of the counting transition in seconds |
| `from` | `number` | `0` | Starting value for the initial animation |

### Returns

| Name | Type | What it is |
|---|---|---|
| `value()` | `() -> number` | The instantaneous unrounded animated number |
| `counting()` | `() -> boolean` | `true` while the count transition is running |
| `skip()` | `() -> ()` | Immediately snaps the number to the final target value |
| `done` | `Lucy.Signal` | Fires whenever the count reaches the target number |

Format `counter.value()` with [`Lucy.Format.number`](../utils.md#formatnumber) to
display clean integers with commas.

## Example: Club Lucy coin reward

Display animated coins after winning a dance-off, playing a coin sound when the
count finishes:

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

The [Text](../../components/text.md) component provides this built in via the
`value` and `count` props: `Lucy.Text.new({ value = coins, count = true })`.
