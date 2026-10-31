<!-- Made by scripts/skills.ts from docs/guide/accessibility.md. Edit the doc, not this file. -->
# Accessibility

Lucy aims to make the accessible choice the default one, so a game gets it
without extra work. This page lists what it does today and what is still to
come.

## Colour and contrast

Every colour pair a component puts text on is worked out, not hand picked:

- **Text on a fill** (buttons, badges, toasts, checked boxes) uses the theme's
  `*Foreground` tokens. Each is the fill's own colour taken to its darkest or
  lightest, like red-950 or red-200 on red, so it reads as part of the fill
  rather than black or white stuck on top.
- **Alerts** use a pale wash of their colour with text in a deep shade of it
  (`DestructiveSubtle` and `DestructiveSubtleForeground`, and so on).
- **Every one reaches WCAG AA**, a contrast of 4.5:1 for body text. If the
  chosen shade falls short, Lucy moves it lighter or darker in OKLCH, keeping
  its hue, until it reaches 4.5:1. This holds for every base colour, every
  primary hue and both themes, and Lucy's specs check all of them.

A theme of your own gets the same with `Lucy.Tokens.onColor`:

```luau
local themes = Lucy.Tokens.themesFor("slate", { primary = "lime" })
themes.dark.Primary = "$Lime300"
themes.dark.PrimaryForeground = Lucy.Tokens.onColor("$Primary")
```

For your own UI, `Lucy.Oklab.contrast(a, b)` gives the WCAG ratio between two
colours, and `Lucy.Oklab.onColor(fill)` gives readable text for a fill. See
[Theming](../reference/theming.md).

Don't let colour carry meaning alone. A toast or alert has a title that says
what happened; give status icons a label too.

## Keyboard and gamepad

Everything that can be pressed can be reached without a mouse or touch:

- Tab and the arrow keys move focus on a keyboard, the thumbstick and D-pad on
  a gamepad. The focused control shows a focus ring in the theme's `Ring`
  colour.
- A modal or menu keeps focus inside it until it closes, then gives it back.
- Escape and the gamepad's B button go back: they close the top modal or call
  the screen's `onBack`.
- `defaultFocus` picks where focus starts on each screen. See
  [Scenes](scenes.md).

## Sizes

On touch devices the controls grow to the `touch` density: a medium control is
44 px high, the size touch guidelines ask for. On a TV, text and controls grow
again so they read from across the room. Both follow the device on their own.
See [Theming](../reference/theming.md#densities).

## Still to come

Roblox players can set a few accessibility options in the Roblox menu, and Lucy
doesn't follow them yet:

| Roblox setting | What Lucy would do |
|---|---|
| Reduced motion (`GuiService.ReducedMotionEnabled`) | Skip or shorten tweens, slides and spinners |
| Text size (`GuiService.PreferredTextSize`) | Scale the `Text*` tokens, and the controls with them |
| Background transparency (`GuiService.PreferredTransparency`) | Make see-through panels and the modal scrim more solid |

Other options under consideration:

- A **high contrast** theme option that raises the target from AA (4.5:1) to AAA
  (7:1) for every pair.
- A check for **colour vision deficiencies**, so status colours stay apart for
  players who can't tell red from green.
