<!-- Made by scripts/skills.ts from docs/reference/composables/use-sort.md. Edit the doc, not this file. -->
# useSort

`Lucy.useSort` sorts any list by one or more keys (a grid of cards, a shop
list). [`useTable`](use-table.md) uses it under the surface.

Unlike `useTable`, which wraps each entry into a table row with `row:value()`,
`useSort` returns your original items sorted in `items()`.

## Usage

```luau
local sortModel = Lucy.useSort(options)
```

### Options

`useSort` takes the same options as [`useTable`](use-table.md), without `rowId`
or `manual`:

| Option | Type | Default | What it does |
|---|---|---|---|
| `data` | `array \| Ref \| () -> array` | required | Items to sort |
| `columns` | `array` | required | Sort keys and compare functions |
| `sorting` | `table \| Ref \| false` | `false` | Starting sort |
| `multi` | `boolean` | `false` | Allows secondary columns as tiebreakers |
| `sortable` | `boolean` | `true` | `false` turns sorting off |
| `removable` | `boolean` | `true` | A third toggle clears that key from the sort |
| `descFirst` | `boolean` | `false` | First toggle sorts descending |

### Returns

Returns the same methods as `useTable`, plus:

| Name | Type | What it is |
|---|---|---|
| `items()` | `() -> array` | Your items in sorted order |
| `sort(list)` | `(list: array) -> array` | Sorts another list with the same rules |

## Example: emote shop sorting

Sort emote cards by rarity, style and name using
[SortButton](../../components/sort-button.md):

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
