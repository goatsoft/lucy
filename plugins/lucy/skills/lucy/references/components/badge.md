<!-- Made by scripts/skills.ts from docs/components/badge.md. Edit the doc, not this file. -->
# Badge

A small label for a status or a count, such as "New" on a shop item.

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space2",
    children = {
        Lucy.Badge.new({ text = "New" }),
        Lucy.Badge.new({ text = "Owned", variant = "secondary" }),
        Lucy.Badge.new({ text = "Sold out", variant = "destructive" }),
        Lucy.Badge.new({ text = "128 BPM", variant = "outline" }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `text` | string | `"Badge"` | yes | The label |
| `variant` | string | `"default"` | yes | `default`, `secondary`, `destructive` or `outline` |
| `visible` | boolean | `true` | yes | Shows or hides the badge |

It also takes the [props every component takes](index.md#using-a-component).

## Examples

A badge for each variant:

```luau
for _, variant in { "default", "secondary", "destructive", "outline" } do
    Lucy.Badge.new({ text = variant, variant = variant, Parent = row })
end
```

A count of track requests that follows a value:

```luau
local requests = Lucy.ref(3)

Lucy.Badge.new({
    text = function() return tostring(requests()) end,
    variant = "destructive",
    visible = function() return requests() > 0 end,
    Parent = queueTab,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Badge")`.
