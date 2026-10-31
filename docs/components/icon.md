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

Apart from the few [icons Lucy draws](../guide/icons.md#icons-lucy-draws) in its
own components, icons come from your game. It registers a map of names to
images once, before it builds any UI:

```lua
Lucy.Icon.register({
    ["game:coin"] = { image = 1234567 },
    ["game:logo"] = { image = 7654321, tint = false },
})
```

Write the map yourself for your own images, or let the lucy-icons build make it
from any [Iconify](https://icon-sets.iconify.design) icon you name in your
code, such as `"lucide:heart"`. [Add icons](../guide/icons.md) covers both,
with every field of the map.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `icon` | string or number | `""` | yes | A registered name, an asset id or a url |
| `size` | string or number | `"md"` | yes | `sm` (16 pixels), `md` (20), `lg` (24), or a number of pixels. A quarter larger on TV |
| `variant` | string | `"default"` | yes | The colour: `default` (the text colour), `muted`, `primary`, `destructive`, `success`, `warning` or `info` |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

A name that was never registered draws nothing and warns once in the output,
so the rest of the screen still builds. Register before you build: an icon
does not change when a name is registered later.

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
