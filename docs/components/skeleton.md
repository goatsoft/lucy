---
title: Skeleton
description: A pulsing placeholder while content loads.
---

# Skeleton

A grey shape that pulses while content loads, in place of the text or picture
that will be there. The pulse stops while it is hidden and when it is destroyed.

```lua
Lucy.Skeleton.new({ size = UDim2.fromOffset(250, 16), Parent = card })
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `visible` | boolean | `true` | yes | Shows or hides it |
| `size` | UDim2 | full width, 16 px tall | | Its size |
| `circle` | boolean | `false` | | Makes it round, for avatars |

It also takes the [props every component takes](index.md#using-a-component).

## Examples

A placeholder profile card:

```lua
Lucy.Stack.new({
    gap = "Space2",
    children = {
        Lucy.Skeleton.new({ size = UDim2.fromOffset(48, 48), circle = true }),
        Lucy.Skeleton.new({ size = UDim2.fromOffset(160, 16) }),
        Lucy.Skeleton.new({ size = UDim2.fromOffset(100, 12) }),
    },
    Parent = card,
})
```

Show it until data arrives:

```lua
local loading = Lucy.ref(true)

Lucy.Skeleton.new({ visible = loading, Parent = card })

task.spawn(function()
    loadProfile()
    loading(false)
end)
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Skeleton")`.
