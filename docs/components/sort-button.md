---
title: SortButton
description: A column heading that sorts a list when pressed.
---

# SortButton

A heading that sorts a list, the way a table's header does, for lists that are
not tables: a grid of emote cards, a row of shop items, a friends list drawn
your own way. Press it to sort by that column, again to flip the order, and a
third time to stop sorting by it. [DataGrid](data-grid.md)'s headers are
SortButtons.

It works with [`useSort`](../reference/composables/use-sort.md) or
[`useTable`](../reference/composables/use-table.md). With `multi` on, several
columns sort together: the first pressed leads, and each one pressed after it
breaks the ties of the ones before. A small number shows each column's place
while more than one sorts.

```luau
local RARITY = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }

local emotes = Lucy.useSort({
    data = owned,
    columns = {
        { key = "name", header = "Name" },
        { key = "style", header = "Style" },
        { id = "rarity", header = "Rarity", get = function(emote) return RARITY[emote.rarity] end, descFirst = true },
    },
    sorting = { { id = "rarity", desc = true } },
    multi = true,
})

Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    children = {
        Lucy.SortButton.new({ sort = emotes, column = "name" }),
        Lucy.SortButton.new({ sort = emotes, column = "style" }),
        Lucy.SortButton.new({ sort = emotes, column = "rarity" }),
    },
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `sort` | table | | | What it sorts: the result of [`useSort`](../reference/composables/use-sort.md) or [`useTable`](../reference/composables/use-table.md) |
| `column` | string | | | The id of the column it sorts |
| `text` | string | the column's `header` | | The label |
| `align` | string | `"left"` | | `left`, `center` or `right` |
| `disabled` | boolean | `false` | yes | Stops presses. On by itself for a column that does not sort |
| `onClick` | function | | | Called with the handle after it sorts |
| `size` | UDim2 | as wide as its text, `ControlSm` tall | | Its size |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

While its column sorts, the label is bright and `lucy:chevron-up` or
`lucy:chevron-down` shows the direction. To use your own icons, see
[Icons Lucy draws](../guide/icons.md#icons-lucy-draws).

## Methods and events

| Name | What it does |
|---|---|
| `button:click()` | What a press does: sorts, then calls `onClick` |
| `button.Activated` | A signal fired on each press |
| `button.label` | The label |
| `button.icon` | The direction [Icon](icon.md) |
| `button.priority` | The label with the column's place in the sort |

A press reports `activate`, for [game sounds](../reference/composables/use-ui-sound.md).

## Preview

In Studio, from the command bar: `Lucy.Preview.show("SortButton")`.
