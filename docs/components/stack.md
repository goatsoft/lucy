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
| `align` | string | `"start"` | | Across the stack: `start`, `center`, `end`, `stretch` (each child fills the stack's width in a column, its height in a row) or `baseline` (a row's texts on one baseline, see below) |
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

`direction`, `gap`, `align`, `justify`, `padding`, `size` and `automaticSize` can
change with the device or input. Pass a table instead of a value (or a getter,
for a layout that follows your game's state):

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

## Baseline

A row with `align = "baseline"` lines up its texts where the letters sit, so a
small line beside a big title reads as one line. The children sit
aligned at the bottom, and each text is lifted onto the biggest one's baseline. A
child's text is the child itself or its first text descendant (a Marquee), and
hidden children do not count.

```luau
Lucy.Stack.new({
    direction = "horizontal",
    align = "baseline",
    gap = "Space3",
    children = {
        Lucy.Text.new({ text = "THE LAB", variant = "h2", autoWidth = true }),
        Lucy.Text.new({ text = "Dances, packs and potions", variant = "muted", autoWidth = true }),
    },
    Parent = header,
})
```

Dialog and Sheet headings use it on short screens, where the description sits
beside the title.

## Grow

`Lucy.Stack.grow(child, when?)` lets a child take the room its stack has left
along the stack's direction: the preview above a shop's buy button, a list under
a header. `when` is a boolean or a getter (always by default); while it is
false the child keeps its own size. Give the child a size of 0 on that axis.

```luau
local preview = Lucy.new("Frame")({ Size = UDim2.fromScale(1, 0) })
Lucy.Stack.grow(preview)
Lucy.Stack.new({
    size = UDim2.fromOffset(300, 400),
    gap = "Space3",
    children = { preview, buyButton },
    Parent = column,
})
```

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

A menu whose buttons all take its full width:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-stack-5-light.webp" alt="Stack example" loading="lazy"><img class="example-dark" src="/images/examples/components-stack-5-dark.webp" alt="Stack example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    align = "stretch",
    gap = "Space2",
    size = UDim2.fromOffset(240, 0),
    automaticSize = Enum.AutomaticSize.Y,
    children = {
        Lucy.Button.new({ text = "Request a song" }),
        Lucy.Button.new({ text = "Cheer the dancer" }),
        Lucy.Button.new({ text = "Leave the floor", variant = "ghost" }),
    },
    Parent = parent,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Stack")`.
