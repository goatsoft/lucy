---
title: Skeleton
description: A pulsing placeholder while content loads.
---

# Skeleton

A grey shape that pulses while content loads, in place of the text or picture
that will be there. The pulse stops while it is hidden and when it is destroyed.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-skeleton-light.webp" alt="Skeleton example" loading="lazy"><img class="example-dark" src="/images/examples/components-skeleton-dark.webp" alt="Skeleton example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space2",
    children = {
        Lucy.Skeleton.new({ size = UDim2.fromOffset(360, 120) }),
        Lucy.Skeleton.new({ size = UDim2.fromOffset(240, 16) }),
        Lucy.Skeleton.new({ size = UDim2.fromOffset(150, 12) }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `visible` | boolean | `true` | yes | Shows or hides it |
| `size` | UDim2 | full width, 16 px tall | | Its size |
| `circle` | boolean | `false` | | Makes it round, for avatars |

It also takes the [props every component takes](index.md#using-a-component).

## Examples

A placeholder card for a Crew member:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-skeleton-2-light.webp" alt="Skeleton example" loading="lazy"><img class="example-dark" src="/images/examples/components-skeleton-2-dark.webp" alt="Skeleton example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space2",
    children = {
        Lucy.Skeleton.new({ size = UDim2.fromOffset(48, 48), circle = true }),
        Lucy.Skeleton.new({ size = UDim2.fromOffset(160, 16) }),
        Lucy.Skeleton.new({ size = UDim2.fromOffset(100, 12) }),
    },
    Parent = crewCard,
})
```

Show it until data arrives:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-skeleton-3-light.webp" alt="Skeleton example" loading="lazy"><img class="example-dark" src="/images/examples/components-skeleton-3-dark.webp" alt="Skeleton example" loading="lazy"></figure>

```luau
local loading = Lucy.ref(true)

Lucy.Skeleton.new({ visible = loading, Parent = topDancers })

task.spawn(function()
    loadTopDancers()
    loading(false)
end)
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Skeleton")`.
