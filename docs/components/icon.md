---
title: Icon
description: A small picture in the theme's colours, by name or asset id.
---

# Icon

A small picture that takes its colour from the theme, so it changes with light
and dark mode and with the text around it. Name it, or give it an asset id.

```lua
Lucy.Icon.new({ icon = "lucide:heart", variant = "destructive", Parent = row })
```

## Registering icons

Lucy ships no icons. Your game registers its own once, before it builds any UI.

The easiest way is the icon build,
[lucy-icons](https://github.com/goatsoft/lucy/tree/main/libs/icons): name any
of thousands of open icons in your code, such as `"lucide:heart"`, and it packs
the ones you use into a few uploaded sheets and writes this map for you. Or
write the map yourself:

```lua
Lucy.Icon.register({
    ["lucide:heart"] = { image = 1234567, rect = { 0, 0, 96, 96 } },
    ["lucide:star"] = { image = 1234567, rect = { 96, 0, 96, 96 } },
    ["game:logo"] = { image = 7654321, tint = false },
})
```

Each name maps to:

| Field | What it is |
|---|---|
| `image` | The asset id or url of the picture, or of a sheet holding many icons |
| `rect` | Optional: `{ x, y, width, height }` of the icon's cell in a sheet, in pixels |
| `tint` | Optional: `false` keeps the picture's own colours (a logo); otherwise the theme colours it |

Icons that the theme colours should be drawn in white on a clear background.
Keeping many icons in one sheet means one upload and one download for all of
them. `Lucy.Icon.register` returns a function that removes those names again.
Names are global to the game, so register each once.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `icon` | string or number | `""` | yes | A registered name, an asset id or a url |
| `size` | string or number | `"md"` | yes | `sm` (16 pixels), `md` (20), `lg` (24), or a number of pixels. A quarter larger on TV |
| `variant` | string | `"default"` | yes | The colour: `default` (the text colour), `muted`, `primary`, `destructive`, `success`, `warning` or `info` |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

A name that was never registered fails `Lucy.Icon.new`. Register before you
build: an icon does not change when a name is registered later.

`Lucy.Icon.has(name)` tells you whether a name is registered, and
`Lucy.Icon.resolve(value)` what it would draw.

## Examples

An icon before a label:

```lua
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space2",
    align = "center",
    children = {
        Lucy.Icon.new({ icon = "lucide:music", variant = "muted" }),
        Lucy.Text.new({ text = "Now playing", autoWidth = true }),
    },
    Parent = header,
})
```

As the media of a list row:

```lua
Lucy.Item.new({
    title = "Streamer mode",
    media = Lucy.Icon.new({ icon = "lucide:radio", size = "lg" }),
    actions = { Lucy.Switch.new({ checked = streamerMode }) },
    Parent = settings,
})
```

For artwork that keeps its colours, such as a song cover, use [Image](image.md).

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Icon")`.
