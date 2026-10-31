---
title: Theming
description: Every theme option, colour token, primitive and density value, the Tokens helpers, app.theme's methods and how style rules work.
order: 3
---

# Theming

How Lucy's themes are put together, and everything you can set. For a walk
through, see [Add a theme](../guide/themes.md).

Lucy styles with Universal Styling. The tokens live as attributes on style
sheets; components and your own rules point at them with `$Name`. Switching theme
or density points the sheets at another set of values, so every linked gui
restyles at once.

```
Folder <namePrefix>Styles (ReplicatedStorage)
├─ Tokens                 primitives: palette, radius, space, fonts, stroke
├─ Theme_light, _dark...  colour tokens, one sheet per theme
├─ Density_default, _touch, _tv   control heights and type scale
└─ Design                 the active theme + density, and every style rule
```

## App options

| Option | Default | What it does |
|---|---|---|
| `theme` | `"dark"` | The theme to start in |
| `baseColor` | `"zinc"` | Base colour for the built in light and dark themes |
| `primary` | the base colour | Palette hue that tints `Primary` and `Ring` |
| `themes` | built from `baseColor` and `primary` | Your own set of themes, replacing the built in ones |
| `primitives` | `Lucy.Tokens.primitives` | Your own primitives, replacing the whole set |
| `densities` | `Lucy.Tokens.densities` | Your own densities, replacing the whole set |
| `density` | follows the device | Pins a density |
| `styleParent` | `ReplicatedStorage` | Where the style sheets folder goes |

Base colours: `zinc`, `slate`, `gray`, `neutral`, `stone`, `mauve`, `olive`,
`mist`, `taupe`. Primary hues: `red`, `orange`, `amber`, `yellow`, `lime`,
`green`, `emerald`, `teal`, `cyan`, `sky`, `blue`, `indigo`, `violet`, `purple`,
`fuchsia`, `pink`, `rose` (the base colours work too).

## State keys

| Key | Value | Writing it |
|---|---|---|
| `theme` | the theme's name | switches the theme; an unknown name warns and is put back |
| `density` | `"default"`, `"touch"` or `"tv"` | switches the density; Lucy also sets it when the device changes, unless `density` is pinned |

## Colour tokens

Every theme has these. The light and dark columns show the built in themes for a
base colour `c` and primary hue `p` (`c-950` is the base colour's 950 shade).
Without a `primary`, the `p` values fall back to the base colour shades shown.

| Token | Colours | Light | Dark |
|---|---|---|---|
| `Background` | the page behind everything | White | c-950 |
| `Foreground` | text on the background | c-950 | c-50 |
| `Card`, `CardForeground` | panels and their text | White, c-950 | c-900, c-50 |
| `Popover`, `PopoverForeground` | menus, selects, tooltips | White, c-950 | c-900, c-50 |
| `Primary` | the main action colour | p-600 (or c-900) | p-500 (or c-200) |
| `PrimaryForeground` | text on `Primary` | readable: p-50 (or c-50) or c-950 | readable: p-50 (or c-50) or c-900 |
| `PrimaryHover` | `Primary` hovered | Primary at 90% | Primary at 90% |
| `Secondary`, `SecondaryForeground`, `SecondaryHover` | quieter buttons | c-100, c-900, 80% | c-800, c-50, 80% |
| `Muted`, `MutedForeground` | subdued surfaces and hint text | c-100, c-500 | c-800, c-400 |
| `Accent`, `AccentForeground` | hovered rows and items | c-100, c-900 | c-800, c-50 |
| `Destructive`, `DestructiveForeground`, `DestructiveHover` | delete and danger | Red-600, readable, 90% | Red-400, readable, 90% |
| `Border` | dividers and outlines | c-200 | White at 10% |
| `Input` | field outlines | c-200 | White at 15% |
| `Ring` | the focus ring | p-400 (or c-400) | p-300 (or c-500) |
| `Overlay`, `OverlayTransparency` | the scrim behind modals | Black, 0.5 | Black, 0.3 |
| `Success`, `Warning`, `Info` | status colours | Green-600, Amber-500, Blue-600 | Green-500, Amber-400, Blue-500 |
| `SuccessForeground`, `WarningForeground`, `InfoForeground` | text on a status colour | readable | readable |

**Readable** means worked out for contrast: of white (or the light shade shown)
and the dark shade, whichever has more contrast with its fill, as WCAG 2 measures
it. If neither reaches 4.5:1 (level AA for body text), it is made lighter or
darker in OKLCH, keeping its hue, until it does. So text on a fill stays
readable with any base colour, primary hue or theme of your own built with
`readable`.

"At 90%" means composited over the background, as a browser would: a `Color3`
has no transparency, so Lucy works the blend out when the theme is built.

## Primitives

The same in every theme.

| Token | Value |
|---|---|
| `<Hue><Shade>` | every palette colour, such as `Violet500` or `Zinc950`; shades 50, 100, 200 to 900, 950 |
| `White`, `Black` | |
| `RadiusSm`, `RadiusMd`, `RadiusLg`, `RadiusXl`, `RadiusFull` | 6, 8, 10, 14 px, and fully round |
| `Space0` to `Space6`, `Space8` | 0 to 24 px in steps of 4, and 32 px |
| `FontSans`, `FontSansMedium`, `FontSansSemibold`, `FontSansBold` | Nunito, for text |
| `FontDisplay` | Fredoka, for headings |
| `StrokeThin`, `StrokeThick` | 1 and 2 px |
| `FocusRing` | 3 px |

## Densities

| Token | `default` | `touch` | `tv` |
|---|---|---|---|
| `ControlSm`, `ControlMd`, `ControlLg` | 32, 36, 40 | 40, 44, 48 | 44, 52, 60 |
| `ControlIcon` | 36 square | 44 square | 52 square |
| `TextXs` to `Text4xl` | 12, 14, 16, 18, 20, 24, 30, 36 | same as default | 14, 16, 18, 22, 24, 28, 34, 42 |

Control tokens are `UDim2` heights; text tokens are `TextSize` numbers.

## Lucy.Tokens

| Member | What it is |
|---|---|
| `themesFor(base, { primary })` | the built in `{ light, dark }` themes for a base colour and primary hue |
| `oklch(L, C, H)` | a colour from OKLCH lightness (0 to 1), chroma and hue (degrees) |
| `over(fg, bg, alpha)` | `fg` at `alpha` over `bg`, as a theme value; worked out per theme |
| `mix(a, b, t)` | an even mix of two tokens in Oklab; `t` 0 gives `a`, 1 gives `b` |
| `readable(fill, a, b, min?)` | text for `fill`: `a` or `b`, whichever reads better, moved in lightness if needed to reach `min` (4.5 by default); worked out per theme |
| `name(hue, shade)` | a palette token's name: `name("violet", 500)` is `"Violet500"` |
| `primitives`, `densities`, `themes` | Lucy's own sets, to copy and change |
| `bases` | the base colour names |

`Lucy.Palette` has every colour as OKLCH values, and `Palette.hues` and
`Palette.shades` list them.

`Lucy.Oklab` does the colour maths: `Oklab.contrast(a, b)` gives the WCAG 2
contrast ratio between two colours (1 to 21), `Oklab.luminance(color)` their
relative luminance, and `Oklab.readable(fill, a, b, min?)` the same choice as
`Tokens.readable` for plain colours.

A theme of your own can work out its text the same way:

```luau
local themes = Lucy.Tokens.themesFor("slate", { primary = "lime" })
themes.dark.Primary = "$Lime300"
themes.dark.PrimaryForeground = Lucy.Tokens.readable("$Primary", "$White", "$Slate950")
```

## app.theme

| Method | What it does |
|---|---|
| `get()`, `set(name)` | the current theme; `set` errors on an unknown name (setting `app.state` warns instead) |
| `names()` | every theme's name, sorted |
| `getDensity()`, `setDensity(name)` | the current density |
| `resolve(token)` | the value a token has right now, through aliases: `resolve("Primary")` is a `Color3` |
| `addRules(key, rules)` | adds style rules under a key; does nothing if the key is there |
| `removeRules(key)`, `hasRules(key)` | takes a key's rules out; checks for them |
| `link(gui)` | styles a ScreenGui you made yourself (scenes and portals are linked already) |
| `Changed`, `DensityChanged` | signals, fired with the new name |

## Rules

A rule is a table:

| Field | What it is |
|---|---|
| `selector` | which instances: a class (`TextLabel`), a tag (`.shop-price`), states (`:Hover`, `:Press`), children (`> .x`) and descendants (`>> .x`) |
| `priority` | which rule wins when several match; higher wins |
| `properties` | property values; `$Name` for tokens |
| `transitions` | optional `TweenInfo` per property, for smooth changes |

Lucy's own rules use these priority bands, so pick yours to fit: reset -100,
base 0, variant and size 10, state 20, disabled 30, focus ring 100.

Components carry tags you can match too: `ui-<component>` (such as
`ui-button`), `ui-<component>-<key>-<value>` for variants (`ui-button-variant-outline`),
and the flags `ui-disabled`, `ui-checked`, `ui-selected`, `ui-open`, `ui-focused` and
`ui-focus-visible`.

Styles apply a few frames after a change. Read what an instance shows with
`instance:GetStyled(property)`; the plain property gives the unstyled value.
