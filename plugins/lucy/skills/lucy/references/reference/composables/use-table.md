<!-- Made by scripts/skills.ts from docs/reference/composables/use-table.md. Edit the doc, not this file. -->
# useTable

`Lucy.useTable` sorts rows of data by one or more columns, with natural text
sorting, tiebreakers and direction toggling. It draws nothing itself;
[DataGrid](../../components/data-grid.md) uses it for column headers, and you can
use it for custom lists and boards.

## Usage

```luau
local tableModel = Lucy.useTable(options)
```

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `data` | `array \| Ref \| () -> array` | required | Row data |
| `columns` | `array` | required | Column definitions |
| `rowId` | `(row: any) -> any` | row index | Unique row key |
| `sorting` | `table \| Ref \| false` | `false` | Starting sort `{ id = "key", desc = true }`, or a ref |
| `multi` | `boolean` | `false` | Allows sorting by several columns with tiebreakers |
| `sortable` | `boolean` | `true` | `false` disables sorting for every column |
| `removable` | `boolean` | `true` | A third toggle clears the column from the sort |
| `descFirst` | `boolean` | `false` | First toggle sorts descending instead of ascending |
| `manual` | `boolean` | `false` | Data is already sorted on the server; track sort state without reordering |

### Column options

| Field | Type | What it does |
|---|---|---|
| `key` | `string` | Field name on the row, also used as the column ID |
| `id` | `string` | Explicit column ID when using `get` instead of `key` |
| `get` | `(row) -> any` | Reads a computed value from a row |
| `header` | `string` | Column header label |
| `sortable` | `boolean` | `false` disables sorting for this column |
| `sortFn` | `"auto" \| "number" \| "text" \| fn` | Compare mode (`"auto"` by default) |
| `descFirst` | `boolean` | Sort descending on the first toggle for this column |
| `invert` | `boolean` | Flips sort order (for ranks where 1 is highest) |

### Returns

| Name | Type | What it does |
|---|---|---|
| `rows()` | `() -> { TableRow }` | Sorted rows (`id`, `index`, `original`, `row:value(colId)`) |
| `sorting()` | `() -> SortState` | Current sort state |
| `list()` | `() -> { SortEntry }` | Active sorts in priority order |
| `toggle(columnId)` | `(id: string) -> ()` | Cycles a column through ascending, descending and off |
| `sortedBy(columnId)` | `(id: string) -> "asc" \| "desc" \| false` | Current sort direction for that column |
| `priority(columnId)` | `(id: string) -> number?` | Tiebreaker position (`1` for primary, `2` for second) |
| `canSort(columnId)` | `(id: string) -> boolean` | Whether the column can be sorted |
| `setSorting(sort)` | `(sort: any) -> ()` | Sets the active sort directly |
| `columns` | `array` | Resolved columns list |

## Example: top dancers board

Sort dancers by score, then beat accuracy:

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
