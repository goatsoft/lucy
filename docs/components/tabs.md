---
title: Tabs
description: A tab bar with one panel per tab, showing the picked one.
---

# Tabs

A tab bar with one panel per tab, showing the picked one: a shop's sections, a
booth's queue and effects. The bar is a [Toggle Group](toggle-group.md) where a
tab stays picked.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-tabs-light.webp" alt="Tabs example" loading="lazy"><img class="example-dark" src="/images/examples/components-tabs-dark.webp" alt="Tabs example" loading="lazy"></figure>

```luau
Lucy.Tabs.new({
    items = {
        { value = "emotes", text = "Emotes", content = Lucy.Stack.new({
            direction = "horizontal",
            gap = "Space2",
            children = {
                Lucy.Button.new({ text = "Moonwalk 300", icon = "lucide-extended:coins-filled", variant = "outline" }),
                Lucy.Button.new({ text = "Robot 150", icon = "lucide-extended:coins-filled", variant = "outline" }),
                Lucy.Button.new({ text = "Twirl 50", icon = "lucide-extended:coins-filled", variant = "outline" }),
            },
        }) },
        { value = "outfits", text = "Outfits", content = Lucy.Text.new({ text = "New outfits drop every Friday", variant = "muted" }) },
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `items` | table | | | The tabs, in order (see below) |
| `value` | any | the first tab | yes | The tab shown |
| `variant` | string | `"default"` | yes | The tab bar's look: `default`, `outline`, or `line` for text tabs with a line under the picked one |
| `size` | string | `"md"` | yes | The tab bar's size: `sm`, `md` or `lg` |
| `gap` | spacing | `"Space2"` | | Space between the tab bar and the panels |
| `shoulderButtons` | boolean | `true` | | LB and RB switch tabs while focus is inside |
| `scroll` | boolean | `true` | | A tab bar too long for its room scrolls sideways. `false` makes the bar as wide as its tabs |
| `disabled` | boolean | `false` | yes | Greys every tab out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onValueChange` | function | | | Called with `(value, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

Each tab is a table:

| Field | What it does |
|---|---|
| `value` | What the tab stands for. Required |
| `text` | The tab's text. Defaults to the value. `label` works too |
| `content` | The panel: an Instance, a handle, or a function that returns one |
| `icon` | An [icon](icon.md) name drawn before the tab's text |
| `children` | Anything after the text in the tab's [slot](slot.md), such as a count badge. With an icon or children and no text, the tab shows no text. They take the tab's colours |
| `disabled` | Greys this tab out |

Every panel is built when the tabs are, and kept: switching back to a tab finds
it as the player left it, scrolled to the same place. Tabs fill the width and
grow to fit the panel shown. Put a [Scroll Area](scroll-area.md) in a panel for
long content.

When the player picks a tab, it reports `select` with the tab's value for
[useUiSound](../reference/composables/use-ui-sound.md).

## Gamepad

While focus is anywhere inside the tabs, on the tab bar or in a panel, LB and RB
move to the previous and next tab, skipping disabled ones and wrapping around at
the ends. If focus was in the old panel, it moves to the first thing the player
can select in the new one, otherwise to the new tab. With tabs inside tabs, the
inner ones switch.

A tab bar too long for its room scrolls sideways, its edges fading where there
are more tabs. On touch the player drags it. With a controller or the keyboard,
moving along the tabs scrolls the bar with them, and the picked tab is always
brought into view, however it was picked.

`handle.list` is the tab bar and `handle.panels` maps each tab's value to its
panel frame.

## Methods

| Name | What it does |
|---|---|
| `tabs:select(value)` | Shows that tab, as if the player picked it |

## Examples

Text tabs with a line under the picked one, for the sections of a big menu:

```luau
Lucy.Tabs.new({
    variant = "line",
    items = {
        { value = "moves", text = "Moves", content = buildMoves },
        { value = "packs", text = "Packs", content = buildPacks },
        { value = "drinks", text = "Drinks", content = buildDrinks },
    },
    Parent = shop,
})
```

Every crew member's set list, more than fit across a phone. The bar scrolls:

<!-- preview -->

```luau
local crew = { "DJ Lucy", "Nova", "Beatrix", "Kai", "Juno", "Remy", "Pixel Pulse", "The Glowsticks" }
local items = {}
for _, name in crew do
    table.insert(items, {
        value = name,
        text = name,
        content = function() return Lucy.Text.new({ text = `{name}'s set list`, variant = "muted" }) end,
    })
end

local box = Lucy.new("Frame")({ Size = UDim2.fromOffset(360, 120), BackgroundTransparency = 1, Parent = parent })
Lucy.Tabs.new({ variant = "line", items = items, value = "Kai", Parent = box })
```

Open the shop on a tab kept in app state:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-tabs-2-light.webp" alt="Tabs example" loading="lazy"><img class="example-dark" src="/images/examples/components-tabs-2-dark.webp" alt="Tabs example" loading="lazy"></figure>

```luau
local section = app.state:ref("shop.section")

Lucy.Tabs.new({
    value = section,
    items = {
        { value = "emotes", text = "Emotes", content = buildEmotes },
        { value = "outfits", text = "Outfits", content = buildOutfits },
    },
    Parent = shop,
})

-- From anywhere, such as a "new outfit" toast:
section("outfits")
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Tabs")`.
