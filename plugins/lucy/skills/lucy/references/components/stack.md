<!-- Made by scripts/skills.ts from docs/components/stack.md. Edit the doc, not this file. -->
# Stack

A row or a column that lays out its children with even spacing. Use it to
build most layouts: a menu, a row of buttons, a form.

```lua
Lucy.Stack.new({
    gap = "Space4",
    children = {
        Lucy.Text.new({ text = "Settings", variant = "h2" }),
        Lucy.Switch.new({ label = "Music" }),
        Lucy.Button.new({ text = "Done" }),
    },
    Parent = frame,
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

```lua
Lucy.Stack.new({
    direction = { mobile = "vertical", default = "horizontal" },
    gap = { console = "Space6", touch = "Space4", default = "Space2" },
    children = buttons,
    Parent = frame,
})
```

See [Responsive values](index.md#responsive-values) for every key you can use.

## Examples

Centre a title screen:

```lua
Lucy.Stack.new({
    size = UDim2.fromScale(1, 1),
    align = "center",
    justify = "center",
    gap = "Space6",
    children = {
        Lucy.Text.new({ text = "My Game", variant = "h1", align = "center" }),
        Lucy.Button.new({ text = "Play", size = "lg" }),
    },
    Parent = scene.gui,
})
```

A row with buttons at each end:

```lua
Lucy.Stack.new({
    direction = "horizontal",
    justify = "between",
    size = UDim2.new(1, 0, 0, 40),
    children = {
        Lucy.Button.new({ text = "Back", variant = "ghost" }),
        Lucy.Button.new({ text = "Next" }),
    },
    Parent = footer,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Stack")`.
