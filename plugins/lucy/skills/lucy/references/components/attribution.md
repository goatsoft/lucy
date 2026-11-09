<!-- Made by scripts/skills.ts from docs/components/attribution.md. Edit the doc, not this file. -->
# Attribution

A badge displaying "Built with Lucy" alongside Lucy's mascot head at normal badge height.
For guidelines on displaying attribution in your game, see the [Attribution reference](../reference/attribution.md).

```luau
Lucy.Attribution.new({
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `label` | string | `"Built with"` | yes | Prefix text before the brand name |
| `brand` | string | `"Lucy"` | yes | Brand text |
| `variant` | string | `"default"` | yes | `default`, `light`, `secondary`, `outline`, or `brand` |
| `size` | string | `"md"` | yes | `sm`, `md` (normal badge height, 32 px), or `lg` |
| `shape` | string | `"rounded"` | yes | `rounded` (pill), or `square` (`$RadiusMd`, slightly rounded) |
| `image` | string? | `nil` | yes | Optional image override (asset id). Defaults to Lucy's mascot head |
| `onClick` | ((handle) -> ())? | `nil` | no | Optional click handler. When passed, the badge becomes a button (`ImageButton`) with hover and press states |
| `visible` | boolean | `true` | yes | Shows or hides the badge |

It also takes the [props every component takes](index.md#using-a-component).

## Masthead art and grounds

Lucy's mascot head art adapts cleanly to light and dark backgrounds:

- **Dark grounds** (`default`, `secondary`, `outline`, `brand` on dark themes): the masthead has transparent linework cutouts so the dark card or scene behind it naturally shows through as crisp linework.
- **Light grounds** (`light` variant, or on light themes): uses the linework-restored asset with ink background fill and contour outline, ensuring eyes, headphones, and hair lines remain crisp and do not bleed into white or light cards.

## Examples

### Every variant

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    children = {
        Lucy.Attribution.new({ variant = "default" }),
        Lucy.Attribution.new({ variant = "light" }),
        Lucy.Attribution.new({ variant = "outline" }),
        Lucy.Attribution.new({ variant = "secondary" }),
        Lucy.Attribution.new({ variant = "brand" }),
    },
    Parent = parent,
})
```

### Sizes

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    children = {
        Lucy.Attribution.new({ size = "sm" }),
        Lucy.Attribution.new({ size = "md" }),
        Lucy.Attribution.new({ size = "lg" }),
    },
    Parent = parent,
})
```

### Clickable badge

Passing an `onClick` callback makes the attribution badge clickable with focus and press animations:

```luau
Lucy.Attribution.new({
    onClick = function()
        print("Clicked Lucy attribution")
    end,
    Parent = parent,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Attribution")`.
