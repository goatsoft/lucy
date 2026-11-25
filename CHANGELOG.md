# Changelog

What changed in each version of Lucy on Wally (`goatsoft/lucy`). The npm
packages keep their own: `libs/icons/CHANGELOG.md` and `libs/mcp/CHANGELOG.md`.

## 0.2.0

- **Tooltip**: floating labels and cards attached to screen controls or world
  parts, with hover, focus, press, click, proximity, always and manual
  triggers, centred directional arrows, positioning options (`side`, `align`,
  `placement`, `sideOffset`, `alignOffset`, `avoidCollisions`,
  `collisionPadding`, `arrowPadding`), theme variants, custom variants and
  full `Lucy.Text` or custom component content.
- **Prompt**: a themed replacement for Roblox's `ProximityPrompt` with a
  circular `Kbd` key cap inside a circular `Progress` hold ring, nearest-prompt
  exclusivity, touch support, and `Prompt.restyle` / `Prompt.restyleOne` for
  existing `ProximityPrompt` instances.
- **Circular `Kbd` and `Progress`**: `Kbd` and `Progress` both support
  `shape = "circle"` (and `variant = "circle"`), so a circular key cap can sit
  inside a clockwise progress ring.
- **Text colour variants**: `Text` adds theme colour variants (`default`,
  `primary`, `secondary`, `destructive`, `success`, `warning`, `info`,
  `inverse`, `outline`, `overlay`), and explicit colour variants override a
  parent `Tooltip`'s variant colour.
- **Floating composables**: `useHover`, `useFocus`, `usePress`, `useDismiss`,
  `useDelayGroup` and `useProximity`, backed by `Core/Floating` and
  `World.positionOf`.
- **Fixes**: component state now tears down last when an outer effect scope
  stops, and stories register the docs icon sheet when needed.

## 0.1.0

The first release on Wally.

- Lucy's components, the App (scenes, app state, overlays, actions, and input
  for mouse, keyboard, gamepad and touch), themes on Universal Styling,
  reactivity, icons and Devtools. The docs at https://lucy.goatsoft.io cover
  each one.
- For games that used Lucy from source before this release, one change to the
  look: an App that picks no colours now starts in mauve greys with a violet
  primary, as on the website. `primary = "none"` gives the old black and white
  look. `Lucy.Tokens.spectrum` holds the mascot's magenta, orchid and sky to
  use as named colours.
