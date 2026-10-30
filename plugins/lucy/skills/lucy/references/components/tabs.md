<!-- Made by scripts/skills.ts from docs/components/tabs.md. Edit the doc, not this file. -->
# Tabs

A tab bar with one panel per tab, showing the picked one: a shop's sections, a
booth's queue and effects. The bar is a [Toggle Group](toggle-group.md) where a
tab stays picked.

```lua
Lucy.Tabs.new({
    items = {
        { value = "emotes", text = "Emotes", content = emoteGrid },
        { value = "outfits", text = "Outfits", content = outfitGrid },
    },
    Parent = shop,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `items` | table | | | The tabs, in order (see below) |
| `value` | any | the first tab | yes | The tab shown |
| `variant` | string | `"default"` | yes | The tab bar's look: `default` or `outline` |
| `size` | string | `"md"` | yes | The tab bar's size: `sm`, `md` or `lg` |
| `gap` | spacing | `"Space2"` | | Space between the tab bar and the panels |
| `shoulderButtons` | boolean | `true` | | LB and RB switch tabs while focus is inside |
| `disabled` | boolean | `false` | yes | Greys every tab out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onValueChange` | function | | | Called with `(value, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

Each tab is a table:

| Field | What it does |
|---|---|
| `value` | What the tab stands for. Required |
| `text` | The tab's text. Defaults to the value |
| `content` | The panel: an Instance, a handle, or a function that returns one |
| `children` | Shown in the tab in place of the text, such as an icon |
| `disabled` | Greys this tab out |

Every panel is built when the tabs are, and kept: switching back to a tab finds
it as the player left it, scrolled to the same place. Tabs fill the width and
grow to fit the panel shown. Put a [Scroll Area](scroll-area.md) in a panel for
long content.

When the player picks a tab, it reports `select` with the tab's value for
[useUiSound](../reference/composables.md#useuisound).

## Gamepad

While focus is anywhere inside the tabs, on the tab bar or in a panel, LB and RB
move to the previous and next tab, skipping disabled ones and wrapping around at
the ends. If focus was in the old panel, it moves to the first thing the player
can select in the new one, otherwise to the new tab. With tabs inside tabs, the
inner ones switch.

`handle.list` is the tab bar and `handle.panels` maps each tab's value to its
panel frame.

## Methods

| Name | What it does |
|---|---|
| `tabs:select(value)` | Shows that tab, as if the player picked it |

## Examples

Open the shop on a tab kept in app state:

```lua
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
