<!-- Made by scripts/skills.ts from docs/components/image.md. Edit the doc, not this file. -->
# Image

A picture: a dance icon, a song cover, a shop item. Give it an asset id or any
content url.

```luau
Lucy.Image.new({
    image = move.iconId,
    size = UDim2.fromOffset(64, 64),
    rounded = "lg",
    Parent = card,
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

A song cover that fills its card, cut to fit:

```luau
Lucy.Image.new({
    image = song.coverId,
    fit = "cover",
    size = UDim2.fromScale(1, 1),
    rounded = "md",
    Parent = card,
})
```

A product's own picture from Roblox:

```luau
Lucy.Image.new({
    image = `rbxthumb://type=DeveloperProduct&id={productId}&w=150&h=150`,
    size = UDim2.fromOffset(72, 72),
    Parent = shopRow,
})
```

For a player's headshot, use [Avatar](avatar.md).

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Image")`.
