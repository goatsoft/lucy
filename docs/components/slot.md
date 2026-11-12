---
title: Slot
description: What goes inside a badge, button, tab or option, and how it takes the component's colours.
---

# Slot

A component that holds content is a box with a slot: whatever you put in
goes inside, laid out in a row, and takes the component's colours. Badge,
Button, Toggle and SortButton take `children`; the items of Toggle Group,
Tabs, Select, Radio Group and Accordion take `children` each; Checkbox,
Switch and Collapsible take `children` after their label. Their `text`,
`label` and `icon` props fill the same slot, so you only reach for
`children` when you need more than words and one icon.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-slot-light.webp" alt="Slot example" loading="lazy"><img class="example-dark" src="/images/examples/components-slot-dark.webp" alt="Slot example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space3",
    children = {
        Lucy.Badge.new({ icon = "lucide-extended:music-filled", variant = "secondary" }),
        Lucy.Button.new({
            text = "UNLOCK",
            children = { Lucy.Icon.new({ icon = "lucide-extended:coins-filled" }), "199" },
        }),
        Lucy.Tabs.new({
            items = {
                { value = "moves", text = "Moves", children = { Lucy.Badge.new({ text = "3" }) }, content = moves },
                { value = "packs", text = "Packs", content = packs },
            },
        }),
    },
    Parent = parent,
})
```

## What can go in a slot

`children` is one of these, or a list of them in order:

| Content | What it becomes |
|---|---|
| A string or number | A [Text](text.md) in the component's font, size and colour |
| A handle (`Lucy.Icon.new(...)`, any component) | Its instance, in the row |
| An Instance | Itself, in the row |
| A function `(parent) -> ()` | Called to build into the slot |

In the order: the component's icon first, then its text, then the children
(and a button's key hint last).

## Colours

What is in a slot takes the component's colours, hover, picked and disabled
included:

- the slot's own words (strings in `children`, and the text) take its colour,
  fade, font and size;
- a [Text](text.md) deeper in takes its colour and fade, over the Text's own
  variant, and keeps its size;
- an [Icon](icon.md) takes the colour and fade as `ImageColor3` and
  `ImageTransparency`.

A full colour picture (a flag, an item's art) keeps its own colours with the
`ui-icon-untinted` tag. Parts that are not content, such as a sort button's
or collapsible's chevron, keep theirs too.

## Colouring a component

A rule that sets `TextColor3` on a component only reaches its own text. To
colour a component and everything in its slot, add your rule with
`Slot.foreground`:

```luau
app.theme:addRules("rarity", Lucy.Slot.foreground(".ui-badge.my-legendary", "$Yellow400", 41))

local badge = Lucy.Badge.new({ text = "LEGENDARY", icon = "lucide-extended:crown-filled", Parent = card })
badge.Instance:AddTag("my-legendary")
```

It returns the rule and its twins (one for the slot's words, one for any Text
below, one for any Icon below). Use a priority of 40 or more so it beats the
component's variants.

## API

| Function | What it does |
|---|---|
| `Slot.fill(parent, content, { app?, startOrder? })` | Puts `content` in `parent` in order after `startOrder`; returns the last `LayoutOrder` used. For your own components |
| `Slot.flow(rules, path?)` | The twins of `rules`: for each rule that sets text properties, rules that give the slot's words, Texts and Icons below the same. `path` is the way to the slot's words when they are not the component's direct children (default `" > ."`) |
| `Slot.beside(rootSelector)` | Rules for a slot beside a control (a checkbox's label): Foreground, medium, `TextSm`, faded when the root is `ui-disabled`, with their twins |
| `Slot.foreground(selector, colour, priority?)` | A colour for a component and its slot (priority 40 by default) |
| `Slot.TEXT_TAG` | `"ui-slot-text"`, the tag on a slot's own words |
| `Slot.rules` | The shared rules a component with a slot adds |

Twins sit 11 above the rule they come from: over Text's and Icon's own
variants (10), under a game's rules (40 and up).

