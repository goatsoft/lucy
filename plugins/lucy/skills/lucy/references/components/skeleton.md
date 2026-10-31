<!-- Made by scripts/skills.ts from docs/components/skeleton.md. Edit the doc, not this file. -->
# Skeleton

A grey shape that pulses while content loads, in place of the text or picture
that will be there. The pulse stops while it is hidden and when it is destroyed.

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
