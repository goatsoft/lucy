<!-- Made by scripts/skills.ts from docs/reference/accessibility.md. Edit the doc, not this file. -->
# Accessibility

Everything on this page is built in: a game gets it without extra work. For the
steps to check your own UI, see [Make your UI accessible](../guide/accessibility.md).

## Contrast

Every colour pair a component puts text on is worked out, not hand picked, and
reaches WCAG AA, a contrast of 4.5:1 for body text:

| Pair | Tokens |
|---|---|
| Text on a fill (buttons, badges, toasts, checked boxes) | `PrimaryForeground` on `Primary`, `DestructiveForeground` on `Destructive`, and so on for every fill |
| Alert text on its wash | `DestructiveSubtleForeground` on `DestructiveSubtle`, and the same for `Success`, `Warning` and `Info` |
| Error text | `Destructive` on `Background` and on `Card` |

This holds for every base colour, every primary hue and both themes, and Lucy's
specs check all of them.

How the text colour is chosen:

- It is the fill's own colour taken to its darkest or lightest, like red-950 or
  red-200 on red, so it reads as part of the fill rather than black or white
  stuck on top.
- If that shade falls short of 4.5:1, Lucy moves it lighter or darker in OKLCH,
  keeping its hue, until it gets there.
- On a strong mid colour such as red-600, only a near white reaches 4.5:1, so
  light text there is almost white.

A theme of your own gets the same through `Lucy.Tokens.onColor`, and
`Lucy.Oklab.contrast` measures any pair. Both are in
[Theming](theming.md#lucytokens).

## Focus

Everything that can be pressed can be reached without a mouse or touch:

| Input | What it does |
|---|---|
| Tab, arrow keys | move focus on a keyboard |
| Thumbstick, D-pad | move focus on a gamepad |
| Enter, gamepad A | press the focused control |
| Escape, gamepad B | go back: close the top modal, or call the screen's `onBack` |

- The focused control shows a focus ring in the theme's `Ring` colour, only
  while the player navigates with keys or a gamepad. The ring is drawn inside
  the control's edge, so it never spills over its neighbours or gets cut off.
  On a checkbox, switch or radio it goes round the box, track or circle, not
  the label; on a slider it goes round the thumb.
- A modal or menu keeps focus inside it until it closes, then gives it back to
  where it was.
- Each screen starts focus on its `defaultFocus`, or on the first thing that can
  take focus. See [Scenes](../guide/scenes.md).

How input is routed is in [Architecture](../architecture.md#input-and-focus).

## Sizes

Controls take their heights from the density, which follows the device:

| Density | Device | Medium control |
|---|---|---|
| `default` | mouse and keyboard | 36 px |
| `touch` | phones and tablets | 44 px, the size touch guidelines ask for |
| `tv` | consoles | 52 px, with larger text to read from across the room |

Every value is in [Theming](theming.md#densities).

## Roblox settings

Players set these in the Roblox menu, and Lucy follows them live, while the
game runs.

### Reduce motion

`GuiService.ReducedMotionEnabled`. When it is on, things that move jump to
where they end, and fades stay:

| What | With reduced motion |
|---|---|
| `Lucy.spring` | jumps to each new value |
| `Lucy.tween` of a `Vector2`, `Vector3`, `UDim` or `UDim2` | jumps to each new value |
| `Lucy.tween` of a `Color3` or a number | still fades |
| Colour transitions in style rules | still fade |
| Switch | the thumb jumps across |
| Collapsible | opens and closes at once, chevron included |
| Spinner | stays still and pulses instead of turning |
| Skeleton | still pulses (a fade) |

A tween of a number that moves something, like a rotation, is up to you: give
it a `TweenInfo` that takes no time when `Lucy.Preferences.reducedMotion()` is
true. See [Make your UI accessible](../guide/accessibility.md#animate-through-lucy).

### Text size

`GuiService.PreferredTextSize`. Roblox draws all text larger by itself, so Lucy
leaves the `Text*` tokens alone and makes room for it: each control height
grows by as much as the text in it does.

| Token | Grows with |
|---|---|
| `ControlSm` | `TextXs` |
| `ControlMd` | `TextSm` |
| `ControlLg` | `TextBase` |
| `ControlIcon` | nothing: it holds an icon, not text |

This holds in every density. `useMetric` and `app.theme:resolve` give the grown
heights.

### Background transparency

`GuiService.PreferredTransparency`, a number from 0 to 1, 1 by default. Lucy
multiplies every theme token whose name ends in `Transparency` by it, so 0
makes those backgrounds solid. In the built in themes that is
`OverlayTransparency`, the dimmed backdrop behind dialogs and other modal
overlays. A token of your own, like `PanelTransparency`, follows it the same
way. Transparency used to show a disabled control is set in rules, not tokens,
and stays.

### Still to come

Options under consideration:

- A **high contrast** option that raises the target from 4.5:1 to 7:1 (WCAG AAA)
  for every pair.
- A check for **colour vision deficiencies**, so status colours stay apart for
  players who can't tell red from green.

## Lucy.Preferences

The player's settings as tracked getters: bindings and `computed` that read
them update when they change.

| Member | What it is |
|---|---|
| `reducedMotion()` | `true` when motion should be cut: the game's own setting if it set one, otherwise the Roblox one |
| `setReducedMotion(on)` | sets reduced motion from your game's own settings; `nil` follows Roblox again |
| `textSize()` | the player's text size: `"Medium"` (the default), `"Large"`, `"Larger"` or `"Largest"` |
| `added(size)` | how many pixels taller Roblox draws text of `size` at that text size |
| `transparency()` | how see-through backgrounds should be, from `0` (solid) to `1` (as designed): the game's own setting if it set one, otherwise the Roblox one |
| `setTransparency(value)` | sets it from your game's own settings, kept between 0 and 1; `nil` follows Roblox again |

Text size can't be set: Roblox draws the text, so Lucy only follows it.
