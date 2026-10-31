<!-- Made by scripts/skills.ts from docs/components/separator.md. Edit the doc, not this file. -->
# Separator

A thin line between items, across a column or down a row.

```luau
Lucy.Separator.new({ Parent = menu })
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `orientation` | string | `"horizontal"` | yes | `horizontal` runs across, `vertical` runs down |
| `visible` | boolean | `true` | yes | Shows or hides the line |

It also takes the [props every component takes](index.md#using-a-component).

## Examples

Between sections of a column:

```luau
Lucy.Stack.new({
    gap = "Space4",
    children = {
        Lucy.Text.new({ text = "Audio", variant = "h4" }),
        Lucy.Switch.new({ label = "Music" }),
        Lucy.Separator.new(),
        Lucy.Text.new({ text = "Video", variant = "h4" }),
        Lucy.Switch.new({ label = "Shadows" }),
    },
    Parent = settings,
})
```

Between items in a row. A vertical line takes the full height of what it is in,
so give the row a height:

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    align = "center",
    size = UDim2.new(1, 0, 0, 24),
    children = {
        Lucy.Text.new({ text = "Wins: 12", autoWidth = true }),
        Lucy.Separator.new({ orientation = "vertical" }),
        Lucy.Text.new({ text = "Losses: 4", autoWidth = true }),
    },
    Parent = stats,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Separator")`.
