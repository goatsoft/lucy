<!-- Made by scripts/skills.ts from docs/reference/composables/use-sort.md. Edit the doc, not this file. -->
# useSort

`Lucy.useSort` provides a multi-column sorting engine for arbitrary lists that
are not formatted as tabular records (such as card grids or shop items).
[`useTable`](use-table.md) is built directly on top of `useSort`.

While `useTable` formats rows into record objects with cell getters, `useSort`
returns your original items sorted in an `items` array.

## Usage

```luau
local sortModel = Lucy.useSort(options)
```

### Options

`useSort` accepts the same options as [`useTable`](use-table.md) (excluding
`rowId` and `manual`):

| Option | Type | Default | What it does |
|---|---|---|---|
| `data` | `array | Ref | () -> array` | required | The list of items to sort |
| `columns` | `array` | required | Columns defining sort keys and comparison functions |
| `sorting` | `table | Ref | false` | `false` | Starting sort configuration |
| `multi` | `boolean` | `false` | Enables multi-column tiebreaker sorting |
| `sortable` | `boolean` | `true` | When `false`, sorting is disabled |
| `removable` | `boolean` | `true` | A third toggle clears the column from the sort |
| `descFirst` | `boolean` | `false` | First toggle sorts descending |

### Returns

Returns the same methods as `useTable`, with:

| Name | Type | What it is |
|---|---|---|
| `items()` | `() -> array` | Getter returning your original items array, sorted |
| `sort(list)` | `(list: array) -> array` | Helper to sort any independent array using the same sort rules |

## Example: Club Lucy emote shop sorting

Sort emote shop cards by rarity, style and name using
[SortButton](../../components/sort-button.md) controls:

```luau
local RARITY_RANKS = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }

local ownedEmotes = Lucy.ref({
    { name = "Moonwalk", rarity = "Epic", style = "Retro" },
    { name = "Robot", rarity = "Common", style = "Street" },
    { name = "Shuffle", rarity = "Legendary", style = "Club" },
})

local sortedEmotes = Lucy.useSort({
    data = ownedEmotes,
    columns = {
        { key = "name" },
        { key = "style" },
        {
            id = "rarity",
            get = function(emote) return RARITY_RANKS[emote.rarity] end,
            descFirst = true,
        },
    },
    sorting = { { id = "rarity", desc = true } },
    multi = true,
})

-- Render the sorted items with Lucy.each
Lucy.each(sortedEmotes.items, function(emote)
    return EmoteCard(emote)
end)

-- Clicking a name header adds "name" as the secondary tiebreaker:
sortedEmotes.toggle("name")
```
