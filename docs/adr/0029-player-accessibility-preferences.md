# 0029: Lucy follows the player's reduce motion and text size settings

- Status: accepted (JB, 2026-10-31)
- Date: 2026-10-31

## Context

Roblox players can set accessibility options in the Roblox menu, read on
`GuiService`: `ReducedMotionEnabled` (boolean), `PreferredTextSize`
(`Enum.PreferredTextSize`: Medium, Large, Larger, Largest; Medium by default)
and `PreferredTransparency` (number, 1 by default). All are read only and change
while the game runs.

Two facts from the Roblox docs shape the design:

- For text size, the engine draws text larger by itself: `TextSize` stays the
  same and the glyphs grow. `TextService:GetTextSize` reports the grown height,
  which is how a game measures it. In LucyTests at Medium the added height is 0
  for 12, 14, 16 and 18 px.
- For reduced motion, Roblox suggests setting tween time to 0, or swapping a
  slide for a fade.

## Decision

1. A new core module, **`Preferences`** (`Lucy.Preferences`), holds the settings
   as tracked getters: `reducedMotion()`, `textSize()`, and `added(size)` for the
   measured growth. It is module level, not per App: GuiService is global.
   `setReducedMotion(on)` lets a game's own settings menu override reduced
   motion (`nil` follows Roblox again). Text size has no override, since the
   engine draws it and Lucy can only follow.
2. **Reduced motion: moves jump, fades stay** (JB's pick). In `Animate`, springs
   and tweens of `Vector2`, `Vector3`, `UDim` and `UDim2` jump to each new value;
   tweens of `Color3` and numbers still fade. Style rule colour transitions are
   fades and stay. Components that move by hand follow it: the Switch thumb
   jumps, the Collapsible opens at once (its progress number drives a slide and
   a turn, so it passes an instant `TweenInfo`), the Spinner pulses its ring's
   transparency instead of turning. Skeleton already pulses.
3. **Text size: controls grow, text tokens stay** (JB's pick). Scaling the
   `Text*` tokens as well would grow text twice. `Theme:setTextGrowth(grow)`
   adds `grow(size)` to `ControlSm`, `ControlMd` and `ControlLg` on every
   density sheet, using the text each holds (`TextXs`, `TextSm`, `TextBase`).
   `ControlIcon` holds no text and stays. The App sets growth from
   `Preferences.added` whenever the text size is not Medium, and fires
   `Theme.MetricsChanged` so `useMetric` follows.

## Consequences

- Games get both settings with no code. A number tween that moves something
  (a rotation) is the game's to handle; the docs show the instant `TweenInfo`.
- Specs stand in for the Roblox settings with `Preferences._setDevice` and
  replace `Preferences.added`, since Studio can't change them.
- Text size growth could not be seen in Studio, which always reports Medium;
  it needs a check on a device with a larger text size.
- `PreferredTransparency`, a high contrast option and a colour vision check
  remain to do.
