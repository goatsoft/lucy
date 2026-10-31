---
title: Badge
description: A small label for a status or a count.
---

# Badge

A small label for a status or a count, such as "New" on a shop item.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-badge-light.webp" alt="Badge example" loading="lazy"><img class="example-dark" src="/images/examples/components-badge-dark.webp" alt="Badge example" loading="lazy"></figure>

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

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-badge-2-light.webp" alt="Badge example" loading="lazy"><img class="example-dark" src="/images/examples/components-badge-2-dark.webp" alt="Badge example" loading="lazy"></figure>

```luau
for _, variant in { "default", "secondary", "destructive", "outline" } do
    Lucy.Badge.new({ text = variant, variant = variant, Parent = row })
end
```

A count of track requests that follows a value:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-badge-3-light.webp" alt="Badge example" loading="lazy"><img class="example-dark" src="/images/examples/components-badge-3-dark.webp" alt="Badge example" loading="lazy"></figure>

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
