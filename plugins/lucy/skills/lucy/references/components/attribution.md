<!-- Made by scripts/skills.ts from docs/components/attribution.md. Edit the doc, not this file. -->
# Attribution

A small badge that displays "Built with Lucy" alongside Lucy's mascot head, in
five variants across light and dark themes.

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

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `label` | string | `"Built with"` | yes | Prefix text before the brand name |
| `brand` | string | `"Lucy"` | yes | Brand text |
| `variant` | string | `"default"` | yes | `default`, `light`, `secondary`, `outline` or `brand` |
| `size` | string | `"md"` | yes | `sm` (24 px), `md` (32 px) or `lg` (40 px) |
| `shape` | string | `"rounded"` | yes | `rounded` (pill) or `square` (`$RadiusMd`) |
| `image` | string? | `nil` | yes | Custom image asset id in place of Lucy's mascot head |
| `onClick` | ((handle) -> ())? | `nil` | no | Turns the badge into a button (`ImageButton`) with hover and press states |
| `visible` | boolean | `true` | yes | Shows or hides the badge |

It also takes the [props every component takes](index.md#using-a-component).

## Variants

| Variant | Background | What it looks like |
|---|---|---|
| `default` | `$Card` | Card surface with a thin border and dark linework mascot |
| `light` | Light fill | Bright badge with dark text and crisp ink mascot linework |
| `secondary` | `$Secondary` | Muted surface with a thin border |
| `outline` | Transparent | Border only (`$Border`), showing whatever sits behind it |
| `brand` | Subtle brand tint | Highlighted badge in the theme's accent |

The mascot art swaps between dark and light assets so hair lines, eyes and
headphones stay legible on both dark and light surfaces.

## Examples

### In a settings or credits panel

```luau
Lucy.Panel.new({
    title = "About",
    children = {
        Lucy.Text.new({ text = "Made with Lucy.", variant = "muted" }),
        Lucy.Attribution.new({
            variant = "outline",
            size = "sm",
        }),
    },
    Parent = parent,
})
```

### Sizes and shapes

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    children = {
        Lucy.Attribution.new({ size = "sm" }),
        Lucy.Attribution.new({ size = "md" }),
        Lucy.Attribution.new({ size = "lg" }),
        Lucy.Attribution.new({ shape = "square" }),
    },
    Parent = parent,
})
```

### Clickable badge

Pass `onClick` to make the badge clickable, for opening a credits window or link
notice:

```luau
Lucy.Attribution.new({
    onClick = function()
        app.state:set("ui.credits.open", true)
    end,
    Parent = parent,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Attribution")`.
