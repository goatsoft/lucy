---
title: Grid
description: Rows of equal cells, such as shop items or emotes.
---

# Grid

Lays out its children in rows of equal cells: shop items, emotes, songs,
avatars. Give it a number of columns and the cells share the width, or a
fixed cell size and it fits as many on a row as it can.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-grid-light.webp" alt="Grid example" loading="lazy"><img class="example-dark" src="/images/examples/components-grid-dark.webp" alt="Grid example" loading="lazy"></figure>

```luau
Lucy.Grid.new({
    columns = 3,
    cellHeight = 40,
    gap = "Space2",
    children = {
        Lucy.Button.new({ text = "Moonwalk", icon = "lucide-extended:star-filled", variant = "outline" }),
        Lucy.Button.new({ text = "Robot", icon = "lucide-extended:zap-filled", variant = "outline" }),
        Lucy.Button.new({ text = "Shuffle", icon = "lucide-extended:footprints-filled", variant = "outline" }),
        Lucy.Button.new({ text = "Twirl", icon = "lucide-extended:sparkles-filled", variant = "outline" }),
        Lucy.Button.new({ text = "Wave", icon = "lucide-extended:heart-filled", variant = "outline" }),
        Lucy.Button.new({ text = "Groove", icon = "lucide-extended:music-filled", variant = "outline" }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `columns` | number | | | Cells share the width between this many columns |
| `minCellWidth` | number | | | Fits as many columns as it can with cells at least this wide, then shares the width |
| `cellSize` | UDim2 | 100 by 100 | | Fixed cells, as many on a row as fit. Used when neither of the above is given |
| `cellHeight` | number | | | Cell height in pixels, with `columns` or `minCellWidth` |
| `aspectRatio` | number | `1` | | Width over height, when `cellHeight` is left out |
| `gap` | spacing | `0` | | Space between cells, across and down |
| `padding` | spacing | none | | Space around the inside edge |
| `align` | string | `"start"` | | Where a row that is not full sits: `start`, `center` or `end` |
| `size` | UDim2 | see below | | The grid's size |
| `children` | table | | | Instances, handles or functions to put in it |
| `virtual` | boolean | `false` | | Builds only the cells near the view, see [Long lists](#long-lists) |
| `items` | table | | | With `virtual`: the list, as an array, a ref or a getter |
| `item` | function | | | With `virtual`: draws one cell, `item(entry, index)`, where `index` is a getter |
| `key` | function | the index | | With `virtual`: `key(entry, index)` names a cell, so a new list moves it rather than rebuilding it |
| `visible` | boolean | `true` | yes | Shows or hides the grid |

It also takes the [props every component takes](index.md#using-a-component).

A spacing value is a token name (`"Space0"` to `"Space6"`, `"Space8"`), a
number of pixels or a UDim.

Without a `size`, the grid fills the width and grows in height to fit its rows.
Each child is sized to its cell, so a child's own `Size` does not matter.

`handle.Instance` is the frame and `handle.layout` its UIGridLayout. Put more
children in the frame any time.

## Responsive values

`columns`, `cellSize` and `gap` can change with the device or input. Pass a
table instead of a value:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-grid-2-light.webp" alt="Grid example" loading="lazy"><img class="example-dark" src="/images/examples/components-grid-2-dark.webp" alt="Grid example" loading="lazy"></figure>

```luau
Lucy.Grid.new({
    columns = { mobile = 2, console = 3, default = 5 },
    gap = { touch = "Space3", default = "Space2" },
    children = emoteCards,
    Parent = emoteShop,
})
```

`minCellWidth` follows the grid's own width instead, so the same grid shows
more columns in a wide window than in a narrow one. See
[Responsive values](index.md#responsive-values) for every key you can use.

## Examples

Emote buttons that fill a panel, as many as fit at 96 pixels or more:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-grid-3-light.webp" alt="Grid example" loading="lazy"><img class="example-dark" src="/images/examples/components-grid-3-dark.webp" alt="Grid example" loading="lazy"></figure>

```luau
Lucy.Grid.new({
    minCellWidth = 96,
    gap = "Space2",
    padding = "Space3",
    children = emoteButtons,
    Parent = panel,
})
```

Track cards in three columns, a little wider than they are tall:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-grid-4-light.webp" alt="Grid example" loading="lazy"><img class="example-dark" src="/images/examples/components-grid-4-dark.webp" alt="Grid example" loading="lazy"></figure>

```luau
Lucy.Grid.new({
    columns = 3,
    aspectRatio = 4 / 3,
    gap = "Space3",
    children = trackCards,
    Parent = queue,
})
```

Put a grid in a [Scroll Area](scroll-area.md) when it can grow taller than the
screen.

## Long lists

A shop of hundreds of items is slow to open and slow to scroll when every card
exists at once. With `virtual = true`, the grid is as tall as all its rows, but
only the cells in the view of the [Scroll Area](scroll-area.md) around it, and
two rows either side, exist. They are built as they come near the view and
removed as they leave.

Give it `items` and an `item` function instead of `children`, with `columns`
or `minCellWidth` and a `cellHeight` in pixels:

```luau
Lucy.ScrollArea.new({
    size = UDim2.fromScale(1, 1),
    children = {
        Lucy.Grid.new({
            virtual = true,
            items = emotes,
            key = function(emote) return emote.id end,
            item = function(emote)
                return EmoteCard.new(emote)
            end,
            minCellWidth = 140,
            cellHeight = 180,
            gap = "Space2",
        }),
    },
    Parent = shop,
})
```

When `items` changes, cells with a `key` that is still there move to their new
place; only new ones are built. Filter a shop by setting a new list.

`handle.cellFor(key)` is a cell's frame while it is built, and
`handle.cellCount()` how many cells are built. A virtual grid has no
UIGridLayout: it places its cells itself. With no Scroll Area (or other
ScrollingFrame) around it, it builds every cell.

Pictures in cells that are not built yet have not loaded either. Preload them
with `ContentProvider:PreloadAsync` before the player opens the shop, so a cell
shows its picture the moment it is built.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Grid")`.
