---
title: Gradient
description: One of the theme's gradients on a frame, a panel or a button.
---

# Gradient

One of the theme's gradients on what it is in. A theme names its gradients as
tokens, like its colours, so a gradient changes with the theme and the game
picks it by name.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-gradient-light.webp" alt="Gradient example" loading="lazy"><img class="example-dark" src="/images/examples/components-gradient-dark.webp" alt="Gradient example" loading="lazy"></figure>

```luau
local card = Lucy.new "Frame" {
    Size = UDim2.fromOffset(320, 160),
    Lucy.new "UICorner" { CornerRadius = UDim.new(0, 12) },
    Parent = parent,
}
Lucy.Gradient.new({ gradient = "Primary", Parent = card })
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `gradient` | string | `"Surface"` | yes | The theme's gradient to draw: the token's name after `Gradient` (`"Surface"` is `GradientSurface`) |
| `rotation` | number | `90` | yes | Its direction in degrees: `90` runs top to bottom, `0` left to right |
| `visible` | boolean | `true` | yes | Shows or hides the gradient |

It also takes the [props every component takes](index.md#using-a-component).

The gradient is a `UIGradient` on its parent, so the parent's corners and
outline keep it and its children sit on top. A gradient tints the colour under
it, so while it shows, Lucy makes the parent's fill white (the
`ui-gradient-host` tag) and the gradient's own colours come through. The
parent's transparency still applies.

## Gradients in the theme

Every built in theme has two:

| Token | What it is |
|---|---|
| `GradientSurface` | a card that deepens toward the background, for panels and screens |
| `GradientPrimary` | the primary colour, lit at the top |

Add your own to every theme with `Lucy.Tokens.gradient`. Its stops are colours
from first to last, spaced evenly, or `{ position, colour }` pairs from 0 to 1.
A colour is a token, a `Color3` or a blend such as `Tokens.mix`, worked out per
theme like any other token:

```luau
local Tokens = Lucy.Tokens

local themes = Tokens.themesFor("slate", { primary = "violet" })
for _, theme in themes do
    theme.GradientClub = Tokens.gradient({
        { 0, Tokens.mix("$Background", "$Purple700", 0.45) },
        { 0.6, "$Background" },
        { 1, "$Background" },
    })
end

local app = Lucy.App.new({ themes = themes })
```

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-gradient-2-light.webp" alt="Gradient example" loading="lazy"><img class="example-dark" src="/images/examples/components-gradient-2-dark.webp" alt="Gradient example" loading="lazy"></figure>

```luau
local screen = Lucy.new "Frame" {
    Size = UDim2.fromOffset(360, 200),
    Lucy.new "UICorner" { CornerRadius = UDim.new(0, 16) },
    Parent = parent,
}
Lucy.Gradient.new({ gradient = "Surface", Parent = screen })
Lucy.Stack.new({
    padding = "Space4",
    children = {
        Lucy.Text.new({ text = "Neon Nights", variant = "h3" }),
        Lucy.Text.new({ text = "DJ Lucy · 124 BPM", variant = "muted" }),
    },
    Parent = screen,
})
```

`Lucy.Gradient.colors(app, "Club")` gives a gradient's colours in the current
theme as a `ColorSequence`, for code that draws its own.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Gradient")`.
