---
title: Add a theme
description: Pick your game's colours, let players switch light and dark, make a theme of your own, and style your own UI with the same tokens.
order: 4
---

# Add a theme

Every Lucy component takes its colours, fonts, corners and sizes from the theme.
Change the theme and everything restyles at once, with no Luau running per
instance. This guide goes from picking colours to a theme of your own. The
[theming reference](../reference/theming.md) lists every token and option.

## Pick your colours

Give the App a base colour and, if you like, a primary colour:

```luau
local app = Lucy.App.new({
    theme = "dark",
    baseColor = "slate",
    primary = "emerald",
})
```

- `baseColor` sets the greys: backgrounds, cards, borders and muted text. One of
  `zinc` (the default), `slate`, `gray`, `neutral`, `stone`, `mauve`, `olive`,
  `mist` or `taupe`.
- `primary` tints buttons, switches, sliders, selections and the focus ring.
  Any palette hue: `red`, `orange`, `amber`, `yellow`, `lime`, `green`,
  `emerald`, `teal`, `cyan`, `sky`, `blue`, `indigo`, `violet`, `purple`,
  `fuchsia`, `pink` or `rose`. Leave it out for a black and white look.
- `theme` is the one to start in: `"dark"` (the default) or `"light"`.

You get a light and a dark theme built from these two colours.

## Switch while the game runs

The theme is a value in app state, so anything can change it:

```luau
app.state:set("theme", "light")
```

To let players choose, bind a control to it. This Select switches the whole UI
as soon as a player picks:

```luau
Lucy.Select.new({
    items = { { value = "dark", label = "Dark" }, { value = "light", label = "Light" } },
    value = app.state:ref("theme"),
})
```

Save the choice with the rest of the player's settings and set it again when they
join.

## Make a theme of your own

A theme is a table of colour tokens. Start from the ones Lucy builds and change
what you need. Here a "midnight" theme takes the dark theme and makes it bluer
and darker:

```luau
local Tokens = Lucy.Tokens

local themes = Tokens.themesFor("slate", { primary = "violet" })
themes.midnight = table.clone(themes.dark)
themes.midnight.Background = Tokens.oklch(0.16, 0.04, 270)
themes.midnight.Card = Tokens.oklch(0.2, 0.05, 270)
themes.midnight.Popover = "$Card"
themes.midnight.Primary = "$Fuchsia400"

local app = Lucy.App.new({ themes = themes, theme = "midnight" })
```

- `themes` replaces the light and dark themes Lucy would build, so keep the ones
  you still want in the table, as above.
- Every theme must have the same tokens; cloning one and changing values keeps
  that true. Lucy errors at start if a theme has a token the others don't.
- A value can be a palette colour (`"$Fuchsia400"`), another token
  (`"$Card"`), a colour (`Tokens.oklch(...)` or a `Color3`), or a blend
  (`Tokens.over("$White", "$Background", 0.1)` is white at 10% over the
  background). Blends are worked out per theme, so `PrimaryHover` follows your new
  `Primary` and `Background` without changing it.

## Change fonts, corners and spacing

Fonts, corner radius and spacing are the same in every theme. They live in the
primitives. Copy Lucy's and change what you need:

```luau
local primitives = table.clone(Lucy.Tokens.primitives)
primitives.RadiusMd = UDim.new(0, 4)
primitives.RadiusLg = UDim.new(0, 6)
primitives.FontDisplay = Font.fromEnum(Enum.Font.GothamBlack)

local app = Lucy.App.new({ primitives = primitives, baseColor = "zinc" })
```

`primitives` replaces the whole set, which is why it starts from a copy.

## Style your own UI

Your own instances can use the theme too, so they change with it. Tag them, and
add rules that match the tags:

```luau
app.theme:addRules("shop", {
    { selector = ".shop-price", properties = { TextColor3 = "$Warning", FontFace = "$FontSansBold" } },
    { selector = ".shop-card", properties = { BackgroundColor3 = "$Card" } },
    { selector = ".shop-card:Hover", priority = 20, properties = { BackgroundColor3 = "$Accent" } },
})

Lucy.new "TextLabel" {
    Tags = { "shop-price" },
    Text = "250",
    Parent = card,
}
```

- A selector matches tags with `.name`, like CSS classes, and states with
  `:Hover` and `:Press`.
- Values starting with `$` are tokens. Use them instead of fixed colours, or the
  instance won't follow the theme.
- Rules apply a few frames after a change. To read the colour an instance shows,
  use `instance:GetStyled("TextColor3")`.
- `addRules` with a key that's already added does nothing; `removeRules(key)`
  takes them out.

## Sizes on every device

Control heights and the type scale come from the density: `default` on desktop,
`touch` on phones and tablets (44 pixel touch targets) and `tv` on consoles.
Lucy picks it from the device, so you rarely set it. To pin one, for testing or a
kiosk game, pass `density = "touch"` to `App.new` or set `app.state:set("density", "tv")`.

## Next

- [Theming reference](../reference/theming.md): every token, option and method
- [Build a component](components.md): rules and variants for a component of
  your own
