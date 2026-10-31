---
title: Image
description: A picture from an asset id or a thumbnail.
---

# Image

A picture: a dance icon, a song cover, a shop item. Give it an asset id or any
content url.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-image-light.webp" alt="Image example" loading="lazy"><img class="example-dark" src="/images/examples/components-image-dark.webp" alt="Image example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    align = "center",
    children = {
        Lucy.Image.new({
            image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150",
            size = UDim2.fromOffset(64, 64),
            rounded = "lg",
        }),
        Lucy.Stack.new({
            gap = "Space1",
            size = UDim2.fromOffset(240, 0),
            automaticSize = Enum.AutomaticSize.Y,
            children = {
                Lucy.Text.new({ text = "DJ Lucy", variant = "large" }),
                Lucy.Text.new({ text = "Resident DJ, live in the Booth", variant = "muted" }),
            },
        }),
    },
    Parent = parent,
})
```

For icons that should follow the theme's colours, use [Icon](icon.md).

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `image` | number or string | `""` | yes | An asset id, or a url such as `rbxassetid://...` or `rbxthumb://...` |
| `fit` | string | `"contain"` | yes | How the picture fills its box: `contain`, `cover`, `fill` or `tile` |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `size` | UDim2 | 64 by 64 | | Its size |
| `aspectRatio` | number | | | Keeps width over height, whatever its size |
| `rounded` | string | none | | Rounded corners: `none`, `sm`, `md`, `lg`, `xl` or `full` |

It also takes the [props every component takes](index.md#using-a-component).

What each `fit` does:

| Fit | The picture |
|---|---|
| `contain` | Fits inside the box whole, leaving space at the sides or ends |
| `cover` | Fills the box and is cut off at the sides or ends |
| `fill` | Stretches to the box |
| `tile` | Repeats across the box |

`Lucy.Image.url(value)` turns an asset id into a url, and leaves urls as they
are. An id of `0` gives an empty image.

## Examples

A track cover that fills its card, cut to fit:

```luau
Lucy.Image.new({
    image = track.coverId,
    fit = "cover",
    size = UDim2.fromScale(1, 1),
    rounded = "md",
    Parent = card,
})
```

A coin pack's own picture from Roblox:

```luau
Lucy.Image.new({
    image = `rbxthumb://type=DeveloperProduct&id={coinPackId}&w=150&h=150`,
    size = UDim2.fromOffset(72, 72),
    Parent = shopRow,
})
```

For a player's headshot, use [Avatar](avatar.md).

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Image")`.
