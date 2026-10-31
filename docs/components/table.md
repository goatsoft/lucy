---
title: Table
description: Rows and columns for leaderboards, friends lists and inventories.
---

# Table

Rows and columns: a leaderboard, a friends list, an inventory, match history.
Table draws the rows you give it in the order you give them. For headers the
player can press to sort, use [DataGrid](data-grid.md).

```luau
Lucy.Table.new({
    rows = players,
    rowId = function(player) return player.userId end,
    columns = {
        { key = "rank", header = "#", width = 56, align = "center" },
        { key = "name", header = "Player", width = { fill = 2 } },
        { key = "score", header = "Score", width = { fill = 1 }, align = "right" },
    },
    highlight = function(player) return player.userId == myId end,
    maxHeight = 360,
    Parent = leaderboard,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `columns` | table | | | The columns, see [Columns](#columns) |
| `rows` | array, ref or getter | | | The rows, any tables you like |
| `rowId` | function | the position | | Gives each row an id, so updates change cells instead of rebuilding rows |
| `rowHeight` | number | control height | | Each row's height in pixels |
| `highlight` | function | | | Return `true` for rows to pick out, such as the player's own |
| `striped` | boolean | `false` | | Shades every other row |
| `onRowClick` | function | | | Called with `(row, index)`. Rows become buttons the player can select |
| `empty` | string | | | Shown when there are no rows |
| `maxHeight` | number | | | The body scrolls past this many pixels |
| `virtual` | boolean | `false` | | Builds only the rows near the view, see [Long lists](#long-lists) |
| `onEndReached` | function | | | Called when the player scrolls near the end, see [Long lists](#long-lists) |
| `size` | UDim2 | full width | | With a height, the body fills what the header leaves |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

### Columns

| Field | What it does |
|---|---|
| `key` | The field to show, and the column's id |
| `id` | The column's id, when it has no `key` |
| `get` | A function from the row to the value, instead of `key` |
| `header` | The header text |
| `width` | Pixels, or `{ fill = n }` for a share of the width the fixed columns leave. `{ fill = 1 }` when left out |
| `align` | `left`, `center` or `right` |
| `cell` | A function that draws the cell, see below |

A cell shows the value as text. For anything else, give the column a `cell`
function. It gets `ctx` and returns an instance, a component or text:

- `ctx.row()`: the row, kept up to date as your data changes
- `ctx.value()`: the column's value for that row, also kept up to date
- `ctx.column`: the column

```luau
{
    key = "userId",
    header = "",
    width = 48,
    cell = function(ctx)
        return Lucy.Avatar.new({ userId = ctx.value, size = "sm" })
    end,
}
```

Pass `ctx.value` or `ctx.row` themselves (not their results) to a component's
props, and the cell follows the data.

## Updating rows

Give new data whenever it changes: a new array, a ref you set, or a getter.
Rows are matched by `rowId`, so a changed score changes one cell, and a row that
moves up the board moves rather than being rebuilt. The header stays put while
the body scrolls.

## Long lists

With `virtual = true` and a `rowHeight`, the body is as tall as every row, but
only the rows on screen and a few either side exist. They are built as they
come near the view and removed as they leave, so a board of 10,000 players
costs about what twenty cost.

`onEndReached` is called when the player scrolls within a few rows of the end,
once for each row count. Load the next rows and add them to your data, and it
is ready to fire again:

```luau
local players = Lucy.ref({})

Lucy.Table.new({
    rows = players,
    rowId = function(player) return player.userId end,
    columns = columns,
    virtual = true,
    rowHeight = 40,
    maxHeight = 400,
    onEndReached = function()
        local more = fetchNextPlayers(#players())
        local all = table.clone(players())
        table.move(more, 1, #more, #all + 1, all)
        players(all)
    end,
})
```

## Gamepad

With `onRowClick`, each row can be selected and pressed. Without it, rows are
not selectable, and the body itself can be selected so the player can scroll it.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Table")`.
