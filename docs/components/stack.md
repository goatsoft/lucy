---
title: Stack
description: A row or column that lays out its children.
---

# Stack

A row or a column that lays out its children with even spacing. Use it to
build most layouts: a menu, a row of buttons, a form.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-stack-light.webp" alt="Stack example" loading="lazy"><img class="example-dark" src="/images/examples/components-stack-dark.webp" alt="Stack example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space4",
    children = {
        Lucy.Text.new({ text = "Club settings", variant = "h2" }),
        Lucy.Switch.new({ label = "Light show", checked = true }),
        Lucy.Switch.new({ label = "Crowd cheers" }),
        Lucy.Button.new({ text = "Done", icon = "lucide-extended:sparkles-filled" }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `direction` | string | `"vertical"` | | `vertical` for a column, `horizontal` for a row |
| `gap` | spacing | `0` | | Space between children |
| `padding` | spacing | none | | Space around the inside edge |
| `align` | string | `"start"` | | Across the stack: `start`, `center` or `end` |
| `justify` | string | `"start"` | | Along the stack: `start`, `center`, `end` or `between` |
| `wrap` | boolean | `false` | | Moves children to a new line when they do not fit |
| `size` | UDim2 | see below | | The stack's size |
| `automaticSize` | AutomaticSize | see below | | Overrides how it grows to fit its children |
| `children` | table | | | Instances, handles or functions to put in it |
| `visible` | boolean | `true` | yes | Shows or hides the stack |

It also takes the [props every component takes](index.md#using-a-component).

A spacing value is a token name (`"Space0"` to `"Space6"`, `"Space8"`), a
number of pixels or a UDim.

Without a `size`, a column fills the width and grows in height to fit, and a
row grows both ways to fit. With a `size`, it stays that size.

`handle.Instance` is the container. Put more children in it any time.

## Responsive values

`direction`, `gap`, `align`, `justify`, `padding` and `size` can change with the
device or input. Pass a table instead of a value:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-stack-2-light.webp" alt="Stack example" loading="lazy"><img class="example-dark" src="/images/examples/components-stack-2-dark.webp" alt="Stack example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    direction = { mobile = "vertical", default = "horizontal" },
    gap = { console = "Space6", touch = "Space4", default = "Space2" },
    children = boothButtons,
    Parent = booth,
})
```

See [Responsive values](index.md#responsive-values) for every key you can use.

## Examples

Centre the Lobby title screen:

<!-- preview solo -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-stack-3-light.webp" alt="Stack example" loading="lazy"><img class="example-dark" src="/images/examples/components-stack-3-dark.webp" alt="Stack example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    size = UDim2.fromScale(1, 1),
    align = "center",
    justify = "center",
    gap = "Space6",
    children = {
        Lucy.Text.new({ text = "Club Lucy", variant = "h1", align = "center" }),
        Lucy.Button.new({ text = "Hit the floor", size = "lg" }),
    },
    Parent = scene.gui,
})
```

A row with buttons at each end:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-stack-4-light.webp" alt="Stack example" loading="lazy"><img class="example-dark" src="/images/examples/components-stack-4-dark.webp" alt="Stack example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    direction = "horizontal",
    justify = "between",
    size = UDim2.new(1, 0, 0, 40),
    children = {
        Lucy.Button.new({ text = "Back", variant = "ghost" }),
        Lucy.Button.new({ text = "Next track" }),
    },
    Parent = footer,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Stack")`.
