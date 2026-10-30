---
title: Alert
description: A box that calls attention to a message, such as a server notice.
---

# Alert

A box with a title and a line or two of text that stays on screen: a server
notice, a failed purchase, a rule the player should know. For a message that
comes and goes on its own, use a [toast](toaster.md) instead.

```lua
Lucy.Alert.new({
    title = "Server restarting in 5 minutes",
    description = "Your progress is saved. You will join a new server.",
    variant = "warning",
    Parent = frame,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `title` | string | `""` | yes | The first line. Hidden when empty |
| `description` | string | `""` | yes | The text under it, in a muted colour. Hidden when empty |
| `variant` | string | `"default"` | yes | `default`, `destructive`, `success`, `warning` or `info` |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `icon` | Instance or handle | | | Shown before the text |
| `children` | table | | | More content under the description, such as a button |

It also takes the [props every component takes](index.md#using-a-component).

It fills the width of its parent and grows to fit its text. Its parts are on
the handle: `alert.icon`, `alert.content`, `alert.title` and `alert.description`.

## Looks

A card coloured box with a border. Every variant except `default` colours the
border and the title with the theme's matching colour (`Destructive`,
`Success`, `Warning` or `Info`); the description stays muted.

## Examples

A failed purchase with a way to try again:

```lua
Lucy.Alert.new({
    variant = "destructive",
    title = "Purchase failed",
    description = "You were not charged. Try again in a moment.",
    children = {
        Lucy.Button.new({ text = "Try again", size = "sm", variant = "outline", onClick = retry }),
    },
    Parent = shop,
})
```

A notice that follows game state:

```lua
local restartIn = Lucy.ref(0)

Lucy.Alert.new({
    variant = "warning",
    title = function() return `Server restarting in {restartIn()} minutes` end,
    visible = function() return restartIn() > 0 end,
    Parent = hud,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Alert")`.
