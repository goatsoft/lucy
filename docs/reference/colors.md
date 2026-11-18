---
title: Colours
description: Every colour Lucy ships, as tokens you can use in rules and themes, and the shades each named colour gets.
order: 10.5
---

# Colours

Lucy ships a palette of 17 hues and 9 base colours (greys with a tint), each
in 11 shades from 50 (lightest) to 950 (darkest). Every shade is a token in
every theme: `$Violet500`, `$Zinc950`. Click a swatch to copy its token.

The colours are defined in OKLCH and shown here as Roblox draws them: Lucy
turns each into sRGB, and a vivid shade outside sRGB is clipped to its edge.

## Hues

For `primary`, for [named colours](theming.md#named-colours), and anywhere a
rule or a theme wants a colour.

<ColorPalette />

## Base colours

The greys a theme is built on: `baseColor` picks one for the built in light
and dark themes (`zinc` by default). All but `neutral` have a faint tint: `slate`
and `gray` lean blue (slate the more), `zinc` a touch violet, `mist` teal,
`mauve` purple, `olive` green, and `stone` and `taupe` warm. `neutral` is the
only true grey.

<ColorPalette show="bases" />

## Using them

A token works anywhere a colour does: in a rule, in a theme of your own, as a
named colour.

```luau
local app = Lucy.App.new({
    baseColor = "slate",
    primary = "violet",                     -- tints Primary and Ring
    colors = { hype = "$Yellow400", calm = "$Sky400" },
})

app.theme:addRules("shop", {
    { selector = ".shop-price", properties = { TextColor3 = "$Amber400" } },
})
```

In Luau, `Lucy.Palette[hue][shade]` holds a colour's OKLCH values, and
`Lucy.Oklab.palette("violet", 500)` gives it as a `Color3`. `Lucy.Palette.hues`
and `Lucy.Palette.shades` list them in the order above.

## Shades of a named colour

Each named colour in `colors`, and Primary, gets these shades, worked out per
theme. For `hype`:

| Token | What it is |
|---|---|
| `Hype` | the colour |
| `HypeHover` | the colour at 90% over the background, for hover |
| `HypeForeground` | text on the colour: its own hue at its darkest or lightest, readable to 4.5:1 |
| `HypeSoft` | a quiet wash of it, 16% over a card |
| `HypeMutedTint` | the colour mixed halfway to white |
| `HypeMutedForeground` | quiet text that reads on `HypeSoft` |
| `HypeBorder` | the colour, for outlines |
| `HypeShadow` | a deep shade of it (62% of the way to black), for a hard shadow |

Add your own with `colorRecipes`; see [Named colours](theming.md#named-colours).
