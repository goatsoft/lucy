---
title: useTable
description: Manages sorting for tabular data and column definitions.
order: 7
---

# useTable

`Lucy.useTable` turns raw data arrays and column definitions into reactive sorted
rows. It manages multi-column sorting, tiebreaking, natural text sorting and
direction toggling. It renders no visual elements on its own: components like
[DataGrid](../../components/data-grid.md) use it for column headers, and you can
use it to sort custom lists and leaderboards.

## Usage

```luau
local tableModel = Lucy.useTable(options)
```

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `data` | `array | Ref | () -> array` | required | The raw row data tables |
| `columns` | `array` | required | Column specifications (see below) |
| `rowId` | `(row: any) -> any` | row index | Function deriving a unique row identifier |
| `sorting` | `table | Ref | false` | `false` | Starting sort `{ id = "key", desc = true }`, or a ref to hold it |
| `multi` | `boolean` | `false` | Allows sorting across multiple columns with tiebreakers |
| `sortable` | `boolean` | `true` | When `false`, disables sorting across all columns |
| `removable` | `boolean` | `true` | A third header click clears the column sort |
| `descFirst` | `boolean` | `false` | First header click sorts descending instead of ascending |
| `manual` | `boolean` | `false` | Data is pre-sorted on the server; track sort state without reordering |

### Column specifications

Each entry in `columns` can specify:

| Field | Type | What it does |
|---|---|---|
| `key` | `string` | The table property to read and default column ID |
| `id` | `string` | Explicit column ID (used when `get` is provided instead of `key`) |
| `get` | `(row) -> any` | Value accessor function for computed column values |
| `header` | `string` | Display label for the column header |
| `sortable` | `boolean` | Set to `false` to prevent this column from sorting |
| `sortFn` | `"auto" | "number" | "text" | fn` | Comparison strategy. Default is `"auto"` |
| `descFirst` | `boolean` | Sort descending on first click for this column |
| `invert` | `boolean` | Inverts sort direction (useful for ranks where lower is better) |

### Returns

`useTable` returns a table model object with reactive getters and helper methods:

| Name | Type | What it does |
|---|---|---|
| `rows()` | `() -> { TableRow }` | Getter for the sorted rows. Each row has `id`, `index`, `original`, and `row:value(colId)` |
| `sorting()` | `() -> SortState` | Getter for the current sort configuration |
| `list()` | `() -> { SortEntry }` | Returns active sorts as an array, primary sort first |
| `toggle(columnId)` | `(id: string) -> ()` | Cycles a column's sort: ascending -> descending -> none |
| `sortedBy(columnId)` | `(id: string) -> "asc" | "desc" | false` | Returns the current sort direction for a column |
| `priority(columnId)` | `(id: string) -> number?` | Column tiebreaker priority (1 is primary sort, 2 is second, etc.) |
| `canSort(columnId)` | `(id: string) -> boolean` | Whether the column supports sorting |
| `setSorting(sort)` | `(sort: any) -> ()` | Directly updates the active sort state |
| `columns` | `array` | The resolved column definition list |

## Example: Club Lucy top dancers leaderboard

Sort dancers by score, level, and on-beat accuracy:

```luau
local dancers = Lucy.ref({
    { userId = 101, name = "Nova", score = 14200, hits = 98, steps = 100 },
    { userId = 102, name = "Beatrix", score = 18900, hits = 95, steps = 100 },
    { userId = 103, name = "Kai", score = 14200, hits = 88, steps = 100 },
})

local board = Lucy.useTable({
    data = dancers,
    rowId = function(d) return d.userId end,
    columns = {
        { key = "name", header = "Dancer" },
        { key = "score", header = "Score", descFirst = true },
        {
            id = "accuracy",
            header = "Beat Accuracy",
            get = function(d) return d.hits / d.steps end,
            descFirst = true,
        },
    },
    sorting = { id = "score", desc = true },
    multi = true,
})

-- Print sorted order
for _, row in board.rows() do
    print(row.id, row.original.name, row:value("score"))
end

-- Toggle secondary sort on beat accuracy
board.toggle("accuracy")
```
