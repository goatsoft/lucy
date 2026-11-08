<!-- Made by scripts/skills.ts from docs/reference/format.md. Edit the doc, not this file. -->
# Format

`Lucy.Format` turns values into text. Its functions are plain: they take a
value and return a string, with nothing to set up or clean up, so call them
anywhere.

## Format.number

```luau
Lucy.Format.number(4200)             -- "4,200"
Lucy.Format.number(-1500)            -- "-1,500"
Lucy.Format.number(1234.5678, 2)     -- "1,234.57"
Lucy.Format.number(1234567, 0, ".")  -- "1.234.567"
```

Groups a number's thousands and rounds it to `decimals` places.

| Argument | What it is |
|---|---|
| `n` | The number |
| `decimals` | Places after the point. Default 0 |
| `separator` | Put between groups of three. Default `","` |

Luau's `string.format` pads and rounds (`"%.1f"`, `"%05d"`), but has no
thousands separators.

## With a label

Format a number inside the text around it:

```luau
local coins = app.state:ref("player.coins")

Lucy.Text.new({
    text = function()
        return `{Lucy.Format.number(coins())} coins`
    end,
    Parent = hud,
})
```

A [Text](../components/text.md) with `value` formats its number this way unless
you give it a `format` of your own, and so does a count from
[`useCount`](composables.md#usecount) once you pass it here.
