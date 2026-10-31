<!-- Made by scripts/skills.ts from docs/components/grid.md. Edit the doc, not this file. -->
# Grid

Lays out its children in rows of equal cells: shop items, emotes, songs,
avatars. Give it a number of columns and the cells share the width, or a
fixed cell size and it fits as many on a row as it can.

```luau
Lucy.Grid.new({
    columns = 4,
    gap = "Space2",
    children = cards,
    Parent = shop,
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

```luau
Lucy.Grid.new({
    columns = { mobile = 2, console = 3, default = 5 },
    gap = { touch = "Space3", default = "Space2" },
    children = cards,
    Parent = shop,
})
```

`minCellWidth` follows the grid's own width instead, so the same grid shows
more columns in a wide window than in a narrow one. See
[Responsive values](index.md#responsive-values) for every key you can use.

## Examples

Emote buttons that fill a panel, as many as fit at 96 pixels or more:

```luau
Lucy.Grid.new({
    minCellWidth = 96,
    gap = "Space2",
    padding = "Space3",
    children = emoteButtons,
    Parent = panel,
})
```

Song cards in three columns, a little wider than they are tall:

```luau
Lucy.Grid.new({
    columns = 3,
    aspectRatio = 4 / 3,
    gap = "Space3",
    children = songCards,
    Parent = list,
})
```

Put a grid in a [Scroll Area](scroll-area.md) when it can grow taller than the
screen.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Grid")`.
