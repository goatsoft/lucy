# 0034: Sorting by several columns, for any list (useSort, SortButton)

- Status: accepted (JB, 2026-11-02)
- Date: 2026-11-02

## Context

ADR 0025 put sorting in `Core/TableModel`, behind `useTable` and DataGrid. It
sorts by one column at a time and only for rows it builds itself, and the
sorting header lives inside DataGrid.

Dance Lab's dance menu is a grid of cards, not a table, and wants table style
headings over it (Name, Genre, Rarity) that sort by more than one column:
rarity first, then name for equal rarities. JB asked for a `useSort` that
useTable also uses, and headings like a table's header that multi sort.

A gamepad has no Shift key, so "hold Shift to add a column" does not work.

## Decision

- **`Core/SortModel`** holds the sort and does the sorting. TableModel keeps
  its API and builds rows, then sorts them with a SortModel. `compare` and
  `normalizeColumns` move with it; TableModel re-exports them.
- **`multi`** (off by default) makes the sort a list. A press on a column that
  is not sorted adds it at the end, as the next tiebreaker; a second press
  flips it in place; a third takes it out (flips it back when not
  removable). The first sorted column leads. No modifier key is needed, so it
  works the same with a gamepad, touch and a mouse. Without `multi` the sort
  stays a single `{ id, desc }` or `false`, so saved sorts and DataGrid state
  keep their shape.
- **`priority(id)`** gives a column's place (1, 2, ...) and **`list()`** the
  sorts as a list in either mode.
- **`Lucy.useSort`** sorts any list (`items`, a computed) with a SortModel.
- **`Lucy.SortButton`** is the sorting header, taken out of DataGrid: label,
  direction chevron and, while more than one column sorts, its place. DataGrid
  builds its headers from it and takes `multi`.

## Consequences

- Games can sort card grids and custom lists the same way as tables, with the
  same headers.
- DataGrid's header rules moved to SortButton (`.ui-sort-button`,
  `.ui-sort-label`, `.ui-sort-priority`). Its header buttons keep the
  `ui-datagrid-sort` tag, so a game's own rules for them still match.
- The sort's state shape depends on `multi`: a single sort or `false` without
  it, a list with it.
