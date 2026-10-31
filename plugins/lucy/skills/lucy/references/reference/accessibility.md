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
  while the player navigates with keys or a gamepad.
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

Players can set accessibility options in the Roblox menu. Lucy does not follow
these yet; this is what it will do:

| Setting | Property | What Lucy will do |
|---|---|---|
| Reduce motion | `GuiService.ReducedMotionEnabled` | Moves and slides jump to where they end; colour and transparency fades stay; the spinner pulses instead of turning |
| Text size | `GuiService.PreferredTextSize` | Roblox already draws text larger; Lucy grows control heights to fit it |
| Background transparency | `GuiService.PreferredTransparency` | See-through panels and the modal scrim get more solid |

Other options under consideration:

- A **high contrast** option that raises the target from 4.5:1 to 7:1 (WCAG AAA)
  for every pair.
- A check for **colour vision deficiencies**, so status colours stay apart for
  players who can't tell red from green.
