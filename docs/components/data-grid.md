---
title: DataGrid
description: A table the player can sort by pressing its headers.
---

# DataGrid

A [Table](table.md) whose headers sort it: a shop, a server browser, a list of
friends. Pressing a header sorts by that column, pressing it again flips the
order, and a third press goes back to the order of your data. It works the
same with a mouse, touch or a gamepad.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-data-grid-light.webp" alt="DataGrid example" loading="lazy"><img class="example-dark" src="/images/examples/components-data-grid-dark.webp" alt="DataGrid example" loading="lazy"></figure>

```luau
Lucy.DataGrid.new({
    id = "shop",
    data = {
        { id = "moonwalk", name = "Moonwalk", price = 300, level = 10 },
        { id = "robot", name = "Robot", price = 150, level = 4 },
        { id = "shuffle", name = "Shuffle", price = 50, level = 1 },
        { id = "groove", name = "Groove", price = 500, level = 15 },
    },
    rowId = function(emote) return emote.id end,
    columns = {
        { key = "name", header = "Emote", width = { fill = 2 } },
        { key = "price", header = "Coins", width = 96, align = "right", descFirst = true },
        { key = "level", header = "Level", width = 88, align = "right" },
    },
    sorting = { id = "price", desc = true },
    onRowClick = function(emote) app.toast(`{emote.name}: {emote.price} coins`) end,
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `data` | array, ref, computed or getter | | | The rows, any tables you like |
| `columns` | table | | | The columns, see [Columns](#columns) |
| `rowId` | function | the position | | Gives each row an id, so updates change cells instead of rebuilding rows |
| `sorting` | table or `false` | `false` | yes | The sort, `{ id = "price", desc = true }` |
| `sortable` | boolean | `true` | | `false` turns sorting off |
| `removable` | boolean | `true` | | A third press on a header clears the sort |
| `descFirst` | boolean | `false` | | Every column sorts high to low on the first press |
| `manual` | boolean | `false` | | Your data comes sorted (by your server): keep its order and only track the sort |
| `onSortingChange` | function | | | Called with `(sorting, handle)` when the sort changes |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes every prop of [Table](table.md#props) except `rows`:
`highlight`, `striped`, `onRowClick`, `empty`, `maxHeight`, `virtual`,
`rowHeight`, `onEndReached` and `size`. And it takes the
[props every component takes](index.md#using-a-component).

### Columns

Columns take everything a [Table column](table.md#columns) takes (`key`, `id`,
`get`, `header`, `width`, `align`, `cell`), and how they sort:

| Field | What it does |
|---|---|
| `sortable` | `false` keeps this column's header plain. Columns with no `key` or `get` never sort |
| `sortFn` | `"auto"`, `"number"`, `"text"` or a function `(a, b)` returning a negative number, 0 or a positive number |
| `descFirst` | The first press sorts high to low, for scores and prices |
| `invert` | For values where lower is better, such as a rank |

Text sorts the way a person reads it: `item2` before `item10`, and case does not
count. Rows with no value for the column always go last, and rows with equal
values keep the order of your data.

## The sort in app state

The sort lives at `ui.<id>.sorting`, so you can save it with the player's
settings and put it back, or change it from anywhere:

```luau
app.state:set("ui.shop.sorting", { id = "level", desc = true })
```

A sorted header shows `lucy:chevron-up` or `lucy:chevron-down`. To use your own
icons, see [Icons Lucy draws](../guide/icons.md#icons-lucy-draws).

## Methods and events

| Name | What it does |
|---|---|
| `grid:toggle(columnId)` | What pressing that column's header does |
| `grid.table` | The [Table](table.md) inside |
| `grid.model` | The sorted rows and sort, from [`useTable`](../reference/composables.md#usetable) |

Pressing a header reports `activate`, for [game sounds](../reference/composables.md#useuisound).

## Examples

Sort by a custom order, such as emote rarity:

```luau
local order = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }

{
    key = "rarity",
    header = "Rarity",
    descFirst = true,
    sortFn = function(a, b) return order[a] - order[b] end,
}
```

A server sorted Top Dancers board that loads more as the player scrolls:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-data-grid-2-light.webp" alt="DataGrid example" loading="lazy"><img class="example-dark" src="/images/examples/components-data-grid-2-dark.webp" alt="DataGrid example" loading="lazy"></figure>

```luau
Lucy.DataGrid.new({
    data = dancers,                    -- a ref you add pages to
    columns = columns,
    manual = true,                     -- the server sorts
    onSortingChange = function(sorting) reloadSortedBy(sorting) end,
    virtual = true,
    rowHeight = 40,
    maxHeight = 400,
    onEndReached = loadNextPage,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("DataGrid")`.
