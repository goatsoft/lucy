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
| `text` | string | `"Badge"`, or `""` with an icon or children | yes | The label |
| `icon` | string | | yes | An [icon](icon.md) name drawn before the text, in the badge's colour (`badge.icon`) |
| `children` | table | | | Anything after the text in the badge's [slot](slot.md): strings, components, instances or builders. They take the badge's colours |
| `variant` | string | `"default"` | yes | `default`, `secondary`, `destructive`, `outline` or `overlay` (a see-through fill for a count over a picture: dark with white words in the dark theme, light with dark words in the light one) |
| `shape` | string | `"rounded"` | yes | `rounded`, or `square`: only slightly rounded (`$RadiusXs`, 3 px) and a little tighter, for tags and labels such as a rarity |
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

How many of a dance a player owns, on the corner of its picture. `overlay` is a
see-through fill, so the number reads on any picture:

<!-- preview -->
```luau
local picture = Lucy.Image.new({
    image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150",
    size = UDim2.fromOffset(80, 80),
    Parent = parent,
})
local owned = Lucy.Badge.new({ text = "3", variant = "overlay", Parent = picture.Instance })
owned.Instance.AnchorPoint = Vector2.new(1, 1)
owned.Instance.Position = UDim2.new(1, -4, 1, -4)
```

A badge is a box with a [slot](slot.md): an icon, words, or anything else
sits inside it in a row, in the badge's colours.

```luau
-- An icon alone
Lucy.Badge.new({ icon = "lucide-extended:music-filled", variant = "secondary", Parent = row })

-- An icon and a count
Lucy.Badge.new({ icon = "lucide-extended:users-filled", text = "12", Parent = row })

-- Anything: a level and a star after it
Lucy.Badge.new({
    text = "LV 12",
    children = { Lucy.Icon.new({ icon = "lucide-extended:star-filled" }) },
    Parent = row,
})
```

To colour a badge your own way, use
[`Slot.foreground`](slot.md#colouring-a-component), so its words and icon
change together.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Badge")`.
