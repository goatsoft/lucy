---
title: Toggle Group
description: A row of toggles where the player picks one or several.
---

# Toggle Group

A row of toggles where the player picks one, or several: filter chips, a
category bar, a vote from 1 to 5. Each item is a [Toggle](toggle.md) and looks
like one.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-toggle-group-light.webp" alt="Toggle Group example" loading="lazy"><img class="example-dark" src="/images/examples/components-toggle-group-dark.webp" alt="Toggle Group example" loading="lazy"></figure>

```luau
Lucy.ToggleGroup.new({
    items = { "House", "Disco", "Techno", { value = "hiphop", text = "Hip hop" } },
    value = "House",
    onValueChange = function(genre)
        if genre then app.toast(`Queue: {genre} tracks`) end
    end,
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `items` | table | | | The items, in order (see below) |
| `type` | string | `"single"` | | `single` picks one, `multiple` picks any number |
| `value` | any | `false`, or `{}` for multiple | yes | The picked value, or the list of picked values |
| `required` | boolean | `false` | | Single only: picking the picked item again keeps it picked |
| `variant` | string | `"default"` | yes | `default`, `outline`, or `line`: text only, with a line under the picked items |
| `size` | string | `"md"` | yes | `sm`, `md` or `lg` |
| `orientation` | string | `"horizontal"` | | `horizontal` for a row, `vertical` for a column |
| `gap` | spacing | `"Space1"` | | Space between items |
| `scroll` | boolean | `false` | | A row too long for its room scrolls sideways and keeps the picked item in view. [Tabs](tabs.md) turn it on |
| `disabled` | boolean | `false` | yes | Greys every item out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onValueChange` | function | | | Called with `(value, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

An item is a value (a string or a number, shown as its text) or a table:

| Field | What it does |
|---|---|
| `value` | What the item stands for. Required |
| `text` | Its text. Defaults to the value. `label` works too |
| `icon` | An [icon](icon.md) name drawn before the text |
| `children` | Anything after the text in the item's [slot](slot.md), such as a count or an icon. With an icon or children and no text, the item shows no text. They take the item's colours, picked and hover included |
| `disabled` | Greys this item out |

In a single group, `value` is `false` until something is picked, and picking
the picked item again clears it unless `required` is set. In a multiple group,
`value` is a list, in the order of the items.

When the player picks an item, it reports `select` with that item's value for
[useUiSound](../reference/composables/use-ui-sound.md).

`handle.items` holds the item buttons, in order.

## Methods

| Name | What it does |
|---|---|
| `group:select(value)` | Picks the item, as if the player clicked it |

## Examples

Genre filters the player can combine:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-toggle-group-2-light.webp" alt="Toggle Group example" loading="lazy"><img class="example-dark" src="/images/examples/components-toggle-group-2-dark.webp" alt="Toggle Group example" loading="lazy"></figure>

```luau
local genres = Lucy.ref({})

Lucy.ToggleGroup.new({
    type = "multiple",
    items = { "House", "Techno", "Pop", "Disco" },
    value = genres,
    size = "sm",
    variant = "outline",
    Parent = filters,
})
```

Rate the DJ's set from 1 to 5, with a star in each item:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-toggle-group-3-light.webp" alt="Toggle Group example" loading="lazy"><img class="example-dark" src="/images/examples/components-toggle-group-3-dark.webp" alt="Toggle Group example" loading="lazy"></figure>

```luau
local items = {}
for stars = 1, 5 do
    table.insert(items, { value = stars, children = { Lucy.Icon.new({ icon = "lucide-extended:star-filled" }) } })
end

Lucy.ToggleGroup.new({
    items = items,
    required = true,
    onValueChange = function(stars)
        Remotes.RateSet:FireServer(stars)
    end,
    Parent = ratePanel,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("ToggleGroup")`.
