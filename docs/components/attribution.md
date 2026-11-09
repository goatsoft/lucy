---
title: Attribution
description: A badge showing Built with Lucy with Lucy's mascot head.
---

# Attribution

The Built with Lucy badge lets you display attribution in games and UI created
with Lucy.

It features Lucy's mascot head at normal badge height (32 px) alongside the
brand name, and adapts across dark and light surfaces.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-attribution-light.webp" alt="Attribution example" loading="lazy"><img class="example-dark" src="/images/examples/components-attribution-dark.webp" alt="Attribution example" loading="lazy"></figure>

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
| `variant` | string | `"default"` | yes | `default`, `light`, `secondary`, `outline`, or `brand` |
| `size` | string | `"md"` | yes | `sm`, `md` (normal badge height, 32 px), or `lg` |
| `shape` | string | `"rounded"` | yes | `rounded` (pill), or `square` (`$RadiusMd`, slightly rounded) |
| `image` | string? | `nil` | yes | Optional image override (asset id). Defaults to Lucy's mascot head |
| `onClick` | ((handle) -> ())? | `nil` | no | Optional click handler. When passed, the badge becomes a button (`ImageButton`) with hover and press states |
| `visible` | boolean | `true` | yes | Shows or hides the badge |

It also takes the [props every component takes](index.md#using-a-component).

## Looks and grounds

The badge comes in five variants to fit different grounds and scenes:

| Look | Variant | Ground | Description |
|---|---|---|---|
| Dark | `default` | Card ground (`$Card`) | The default look. Sits on card ground with subtle borders |
| Light | `light` | White / light ground | Pure light ground with dark ink text and ink-filled mascot linework |
| Secondary | `secondary` | Secondary ground (`$Secondary`) | Subdued surface with subtle borders |
| Outline | `outline` | Transparent | Border only (`$Border`), letting the scene or card behind show through |
| Brand | `brand` | Accent surface | Highlights the badge with subtle brand tint |

### Ground and linework mechanics

Lucy's mascot head artwork handles light and dark backgrounds cleanly:

- **Dark grounds** (`default`, `secondary`, `outline`, `brand` on dark themes): the masthead has transparent linework cutouts so the dark card or scene behind it naturally shows through as crisp linework.
- **Light grounds** (`light` variant, or on light themes): uses the linework-restored asset with ink background fill and contour outline, ensuring eyes, headphones, and hair lines remain crisp and do not bleed into white or light cards.

## Examples

### In a settings or credits panel

```luau
Lucy.Panel.new({
    title = "About",
    children = {
        Lucy.Text.new({ text = "Made with Lucy UI framework.", variant = "muted" }),
        Lucy.Attribution.new({
            variant = "outline",
            size = "sm",
        }),
    },
    Parent = parent,
})
```

### Sizes and shapes

The badge supports three sizes (`sm` at 24 px, `md` at 32 px, `lg` at 40 px) and two shapes (`rounded` and `square`):

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

Passing an `onClick` callback makes the attribution badge interactive with hover and press animations, suitable for opening a credits popup or external link notice:

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
