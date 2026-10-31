---
title: Toggle Group
description: A row of toggles where the player picks one or several.
---

# Toggle Group

A row of toggles where the player picks one, or several: filter chips, a
category bar, a vote from 1 to 5. Each item is a [Toggle](toggle.md) and looks
like one.

```luau
Lucy.ToggleGroup.new({
    items = { "House", "Techno", { value = "hiphop", text = "Hip hop" } },
    value = "House",
    onValueChange = function(genre)
        showSongs(genre)
    end,
    Parent = header,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `items` | table | | | The items, in order (see below) |
| `type` | string | `"single"` | | `single` picks one, `multiple` picks any number |
| `value` | any | `false`, or `{}` for multiple | yes | The picked value, or the list of picked values |
| `required` | boolean | `false` | | Single only: picking the picked item again keeps it picked |
| `variant` | string | `"default"` | yes | `default` or `outline` |
| `size` | string | `"md"` | yes | `sm`, `md` or `lg` |
| `orientation` | string | `"horizontal"` | | `horizontal` for a row, `vertical` for a column |
| `gap` | spacing | `"Space1"` | | Space between items |
| `disabled` | boolean | `false` | yes | Greys every item out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onValueChange` | function | | | Called with `(value, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

An item is a value (a string or a number, shown as its text) or a table:

| Field | What it does |
|---|---|
| `value` | What the item stands for. Required |
| `text` | Its text. Defaults to the value |
| `children` | Shown in place of the text, such as an icon |
| `disabled` | Greys this item out |

In a single group, `value` is `false` until something is picked, and picking
the picked item again clears it unless `required` is set. In a multiple group,
`value` is a list, in the order of the items.

When the player picks an item, it reports `select` with that item's value for
[useUiSound](../reference/composables.md#useuisound).

`handle.items` holds the item buttons, in order.

## Methods

| Name | What it does |
|---|---|
| `group:select(value)` | Picks the item, as if the player clicked it |

## Examples

Genre filters the player can combine:

```luau
local genres = Lucy.ref({})

Lucy.ToggleGroup.new({
    type = "multiple",
    items = { "House", "Techno", "Pop", "Rock" },
    value = genres,
    size = "sm",
    variant = "outline",
    Parent = filters,
})
```

A vote from 1 to 5 with a star in each item:

```luau
local items = {}
for stars = 1, 5 do
    table.insert(items, { value = stars, children = { starIcon(stars) } })
end

Lucy.ToggleGroup.new({
    items = items,
    required = true,
    onValueChange = function(stars)
        Remotes.Vote:FireServer(stars)
    end,
    Parent = votePanel,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("ToggleGroup")`.
