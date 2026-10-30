---
title: Panel
description: A card with a header, content and footer.
---

# Panel

A card with a title and description at the top, your content in the middle and
an optional row of buttons at the bottom. Use it for menus, shop items and
settings groups.

```lua
Lucy.Panel.new({
    title = "Loadout",
    description = "Pick a weapon",
    children = { weaponList },
    footer = { Lucy.Button.new({ text = "Save" }) },
    Parent = frame,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `title` | string | `""` | yes | The heading |
| `description` | string | `""` | yes | Text under the heading |
| `visible` | boolean | `true` | yes | Shows or hides the panel |
| `children` | table | | | Instances or handles to put in the content area |
| `footer` | table | | | Instances or handles to put in the footer, such as buttons |
| `size` | UDim2 | fills the width, height fits the content | | The panel's size |
| `maxWidth` | number | | | The widest it gets, in pixels |
| `minWidth` | number | | | The narrowest it gets, in pixels |
| `aspectRatio` | number | | | Keeps a fixed shape, such as `16 / 9` |

It also takes the [props every component takes](index.md#using-a-component).

## Parts

| Name | What it is |
|---|---|
| `panel.header` | The frame with the title and description |
| `panel.content` | The frame that holds `children`; add more to it any time |
| `panel.footer` | The frame that holds `footer` (hidden when there is none) |

## Examples

A fixed width panel with a form:

```lua
local panel = Lucy.Panel.new({
    title = "Settings",
    size = UDim2.fromOffset(360, 0),
    children = {
        Lucy.Switch.new({ label = "Music", checked = true }),
        Lucy.Switch.new({ label = "Sound effects", checked = true }),
    },
    footer = { Lucy.Button.new({ text = "Done", onClick = closeSettings }) },
    Parent = frame,
})
```

Add content later:

```lua
Lucy.Text.new({ text = "Saved 2 minutes ago", variant = "muted", Parent = panel.content })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Panel")`.
