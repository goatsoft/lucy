<!-- Made by scripts/skills.ts from docs/components/stack.md. Edit the doc, not this file. -->
# Stack

A row or a column that lays out its children with even spacing. Use it to
build most layouts: a menu, a row of buttons, a form.

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
| `mount` | string | `"immediate"` | | When a child given as a function is built: `"immediate"` when the stack is made, or `"intersect"` the first time it is scrolled near ([Long lists](#long-lists)) |
| `estimate` | number | `240` | | With `mount = "intersect"`: the room, in pixels along the stack, a child holds until it is built |
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

## Long lists

A long list in a [Scroll Area](scroll-area.md) is built whole by default, even
the sections far below what the player sees. With `mount = "intersect"`, each
child given as a function is built the first time it is scrolled near, the way
a web page watches for an element to intersect the viewport. A wardrobe of a
hundred outfits builds the first few sections when it shows, and the rest as
the player scrolls or moves down with a controller.

```luau
local sections = {}
for _, kind in { "Hats", "Shirts", "Shoes", "Glow sticks" } do
    table.insert(sections, function()
        return Lucy.Stack.new({ gap = "Space2", children = buildOutfitRows(kind) })
    end)
end

Lucy.ScrollArea.new({
    maxHeight = 400,
    children = {
        Lucy.Stack.new({ mount = "intersect", estimate = 320, gap = "Space4", children = sections }),
    },
    Parent = wardrobe,
})
```

- A child is built when its place comes within one view of what the scroll area
  shows, ahead or behind, so the next thing a controller lands on is already
  there. A hidden child is not built until it shows. Once built it is kept.
- Until then each function child is a slot frame holding `estimate` pixels, so
  the scroll bar keeps its length. Give an `estimate` close to a child's real
  size.
- The function is called with its slot. What it parents there stays, and an
  Instance or a handle it returns is put in the slot.
- `handle.slots` lists the slots in order. To hide or reorder a section, set
  `Visible` or `LayoutOrder` on its slot, not on what is built inside it.
- `stack:build(i)` builds child `i` now, and `stack:build()` every child, for
  code that needs something in a section the player has not scrolled to (opening
  the wardrobe on one outfit, say).
- Children that are not functions are placed when the stack is made, as always.

With no scroll area around it, a child is built as soon as it shows.

## Examples

Centre the Lobby title screen:

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
