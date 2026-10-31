---
title: Separator
description: A thin line between items.
---

# Separator

A thin line between items, across a column or down a row.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-separator-light.webp" alt="Separator example" loading="lazy"><img class="example-dark" src="/images/examples/components-separator-dark.webp" alt="Separator example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space3",
    children = {
        Lucy.Text.new({ text = "Neon Nights", variant = "large" }),
        Lucy.Separator.new(),
        Lucy.Text.new({ text = "DJ Lucy · 124 BPM", variant = "muted" }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `orientation` | string | `"horizontal"` | yes | `horizontal` runs across, `vertical` runs down |
| `visible` | boolean | `true` | yes | Shows or hides the line |

It also takes the [props every component takes](index.md#using-a-component).

## Examples

Between sections of a column:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-separator-2-light.webp" alt="Separator example" loading="lazy"><img class="example-dark" src="/images/examples/components-separator-2-dark.webp" alt="Separator example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space4",
    children = {
        Lucy.Text.new({ text = "Audio", variant = "h4" }),
        Lucy.Switch.new({ label = "Music" }),
        Lucy.Separator.new(),
        Lucy.Text.new({ text = "Lights", variant = "h4" }),
        Lucy.Switch.new({ label = "Light show" }),
    },
    Parent = settings,
})
```

Between items in a row. A vertical line takes the full height of what it is in,
so give the row a height:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-separator-3-light.webp" alt="Separator example" loading="lazy"><img class="example-dark" src="/images/examples/components-separator-3-dark.webp" alt="Separator example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    align = "center",
    size = UDim2.new(1, 0, 0, 24),
    children = {
        Lucy.Text.new({ text = "Level 12", autoWidth = true }),
        Lucy.Separator.new({ orientation = "vertical" }),
        Lucy.Text.new({ text = "Combo x8", autoWidth = true }),
    },
    Parent = hud,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Separator")`.
