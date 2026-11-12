<!-- Made by scripts/skills.ts from docs/components/toggle-group.md. Edit the doc, not this file. -->
# Toggle Group

A row of toggles where the player picks one, or several: filter chips, a
category bar, a vote from 1 to 5. Each item is a [Toggle](toggle.md) and looks
like one.

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
| `variant` | string | `"default"` | yes | `default`, `outline`, `line`: text only, with a line under the picked items, or `segmented`: the group is a pill with the picked item raised in it (see below) |
| `size` | string | `"md"` | yes | `sm`, `md`, `lg` or `xl`: each as tall as a [Button](button.md) of the same size |
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
| `visible` | Shows or hides this item: `true`, `false`, a ref or a getter. A hidden item leaves the row and can't be picked. Defaults to `true` |

In a single group, `value` is `false` until something is picked, and picking
the picked item again clears it unless `required` is set. In a multiple group,
`value` is a list, in the order of the items.

When the player picks an item, it reports `select` with that item's value for
[useUiSound](../reference/composables/use-ui-sound.md).

`handle.items` holds the item buttons, in order.

## Segmented

With `variant = "segmented"` the group draws a pill round its items, and the
whole pill is as tall as a control of its `size`: a `lg` segmented group lines
up with a `lg` [Button](button.md), [Select](select.md) or [Input](input.md)
beside it. The items fill the pill inside its padding, muted until picked; the
picked one sits raised on the background colour. Use it for a mode switch in a
header or toolbar, such as BASIC and ADVANCED. [Tabs](tabs.md) take it too.

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
    items = { "House", "Techno", "Pop", "Disco" },
    value = genres,
    size = "sm",
    variant = "outline",
    Parent = filters,
})
```

Rate the DJ's set from 1 to 5, with a star in each item:

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

A VIP ROOM tab that shows up once the player has the pass. The group stays the
same group: the tab just appears, and goes again if the pass does:

```luau
local hasPass = Lucy.ref(true)

Lucy.ToggleGroup.new({
    items = {
        { value = "tonight", text = "TONIGHT" },
        { value = "week", text = "THIS WEEK" },
        { value = "vip", text = "VIP ROOM", visible = hasPass },
    },
    value = "tonight",
    required = true,
    variant = "line",
    Parent = parent,
})
```

A BASIC / ADVANCED switch in an editor's header, as tall as the SAVE button
beside it:

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space2",
    align = "center",
    children = {
        Lucy.ToggleGroup.new({
            items = { { value = "basic", text = "BASIC" }, { value = "advanced", text = "ADVANCED" } },
            value = "basic",
            required = true,
            variant = "segmented",
            size = "lg",
        }),
        Lucy.Button.new({ text = "SAVE", size = "lg" }),
    },
    Parent = parent,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("ToggleGroup")`.
