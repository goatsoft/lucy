# 0025: Table, DataGrid and useTable

- Status: accepted
- Date: 2026-10-31
- Amends: 0021 (data tables move from "not planned" to a core subset)

## Context

ADR 0021 put Table (leaderboards) in 0.1.0 and data tables under "not
planned". Most games show tables beyond a leaderboard: friends lists, shop
inventories, match history, server browsers, trade logs. They need sortable
headers, cells that hold more than text (an avatar, a badge, a button), the
player's own row picked out, and lists of hundreds or thousands of rows that
stay cheap. They do not need what desktop data tables grow into: column
filters, grouping, resizing, pinning, editing in place.

TanStack Table is the model: a headless core (column definitions, sorting
state, a row model computed from the data) kept apart from rendering. Lucy
has the same split already: composables hold reactive state, components
render it.

## Decision

Three pieces, each built on the one before.

### 1. `Lucy.useTable(options)`: the headless core

A composable (ADR 0018) that turns data and column definitions into sorted
rows. No instances.

```luau
local table = Lucy.useTable({
	data = players,                    -- an array, a ref or a getter
	rowId = function(row) return row.userId end,  -- keys rows (defaults to index)
	columns = {
		{ key = "name", header = "Player" },
		{ key = "score", header = "Score", descFirst = true },
		{ id = "kd", header = "K/D", get = function(row) return row.kills / math.max(1, row.deaths) end },
		{ key = "rank", header = "Rank", invert = true },   -- 1st is best
		{ id = "actions", sortable = false },
	},
	sorting = { id = "score", desc = true },  -- a value or a ref; false for none
	removable = true,                  -- a third press clears the sort
	manual = false,                    -- true: data arrives sorted (from a server)
})
table.rows()                -- sorted { id, index, original, value(columnId) }
table.sorting()             -- { id, desc } or false
table.toggle(columnId)      -- the header press: none, first direction, other, none
table.sortedBy(columnId)    -- false | "asc" | "desc"
table.canSort(columnId)
```

A column has `id` (or `key`, which is both id and field), `get` (a value
from the row, instead of `key`), `header`, `sortable`, `sortFn` (`"auto"`,
`"number"`, `"text"` (natural, case blind), or a function `(a, b) -> number`
on values), `descFirst` and `invert`. Missing values sort last either way.
Only one column sorts at a time: shift click has no gamepad or touch
equivalent.

### 2. `Table`: rendering only

Rows and columns in, instances out. No sorting of its own, so a leaderboard
the server already ordered is just a Table.

```luau
Lucy.Table.new({
	columns = {
		{ id = "rank", header = "#", width = 48, align = "center" },
		{ id = "name", header = "Player", width = { fill = 2 }, cell = function(ctx) ... end },
		{ id = "score", header = "Score", width = { fill = 1 }, align = "right" },
	},
	rows = rows,                -- an array, a ref or a getter; keyed by rowId
	rowId = function(row) return row.userId end,
	highlight = function(row) return row.userId == myId end,  -- the player's own row
	onRowClick = function(row) end,   -- rows become pressable and selectable
	striped = false,
	rowHeight = nil,            -- pixels; required by virtual
	virtual = false,            -- build only the rows on screen (and a few more)
	onEndReached = function() end,    -- near the end: load the next page
	empty = "No players yet",
	maxHeight = nil,            -- the body scrolls past it (a ScrollArea)
})
```

- The header stays put while the body scrolls.
- Widths are pixels or `{ fill = n }` shares of what is left.
- A cell is the row's value as text, or `cell(ctx)` returning an instance, a
  handle or a string; `ctx` has `row`, `value`, `column`.
- Rows are keyed by `rowId`, so a score update changes one cell, not the list.
- **Virtual rows:** with `virtual` and a fixed `rowHeight`, the canvas is
  sized for every row and only the rows on screen plus a margin exist; they
  are built as they come near the view and removed as they leave. On gamepad,
  moving selection to the edge of the built rows scrolls the next ones in.
- `onEndReached` fires once when the player scrolls within a few rows of the
  end, and again only after the row count grows.

### 3. `DataGrid`: Table plus useTable

```luau
Lucy.DataGrid.new({ data = players, columns = columns, sorting = { id = "score", desc = true }, ... })
```

It takes useTable's options and Table's, and turns sortable headers into
buttons with a direction icon (`lucy:chevron-up` / `lucy:chevron-down`),
pressable with mouse, touch and gamepad. Its sort lives in app state at
`ui.<id>.sorting`, so a game can save and restore it.

### Not included

Column filters (games filter the data before passing it in), pagination by
pages (virtual rows and `onEndReached` cover long lists), grouping, row
selection with checkboxes, column resizing, pinning, reordering, editing in
place, multi column sorting.

## Consequences

- One sorting core for anything list shaped, usable without Table.
- A leaderboard of thousands of rows costs about what twenty rows cost.
- Table, DataGrid and useTable each get a spec, docs page and story; DataGrid
  and Table count as two components.

## Alternatives considered

- **One Table with sorting built in.** Server ordered lists would carry
  sorting they never use, and sorting could not drive anything but a Table.
- **Porting a web data table whole.** Filters, resizing and pinning are pointer
  and keyboard heavy and do not suit gamepad, touch or TV.
