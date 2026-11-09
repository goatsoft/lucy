---
title: Attribution
description: The Built with Lucy badge, its looks, and how to add attribution to your game.
order: 11
---

# Attribution

The Built with Lucy badge lets you display attribution in games and UI created
with Lucy.

The badge features Lucy's mascot head at normal badge height (32 px) alongside
the brand name, and adapts across dark and light surfaces.

```luau
Lucy.Attribution.new({
    Parent = parent,
})
```

## Looks

The badge comes in five variants to fit different grounds and scenes:

| Look | Variant | Ground | Description |
|---|---|---|---|
| Dark | `default` | Card ground (`$Card`) | The default look. Sits on card ground with subtle borders |
| Light | `light` | White / light ground | Pure light ground with dark ink text and ink-filled mascot linework |
| Secondary | `secondary` | Secondary ground (`$Secondary`) | Subdued surface with subtle borders |
| Outline | `outline` | Transparent | Border only (`$Border`), letting the scene or card behind show through |
| Brand | `brand` | Accent surface | Highlights the badge with subtle brand tint |

### Ground and linework

Lucy's mascot head artwork handles light and dark backgrounds cleanly:

- **Dark grounds** (`default`, `secondary`, `outline`, `brand` on dark themes): the masthead has transparent linework cutouts so the dark card or scene behind it naturally shows through as crisp linework.
- **Light grounds** (`light` variant, or on light themes): uses the linework-restored asset with ink background fill and contour outline, ensuring eyes, headphones, and hair lines remain crisp and do not bleed into white or light cards.

## How to add

### Basic badge in a scene

Add the badge to a HUD, title screen, or credits screen:

```luau
Lucy.Attribution.new({
    Parent = scene.gui,
})
```

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
    Parent = scene.gui,
})
```

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

### Sizes and shapes

The badge supports three sizes and two shapes:

- **Sizes**: `sm` (24 px), `md` (32 px, standard badge height), and `lg` (40 px).
- **Shapes**: `rounded` (pill with fully rounded caps) and `square` (`$RadiusMd`, rounded rectangle).

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
    Parent = scene.gui,
})
```

## Component reference

For all properties, methods, and parts, see the [Attribution component page](../components/attribution.md).

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Attribution")`.
