# 0007: First-class mouse, keyboard, gamepad and touch; Lucy owns focus

- Status: accepted; amended by 0031 (back keys are ButtonB and Backspace, not Escape)
- Date: 2026-10-30

## Context

Roblox games run on PC, console, tablet and phone, often switching input mid-play.
Roblox's defaults work against a designed UI: a white selection image around the
gamepad-selected object, default borders, AutoButtonColor tinting, and no notion
of keyboard Tab focus or "focus-visible".

## Decision

`InputManager` (one per App) publishes `input.mode` (mouse, keyboard, gamepad,
touch), `input.device` (desktop, console, tablet, mobile), `input.density`,
`orientation` and `breakpoint`.

Focus is Lucy's:

- The App sets a blank `SelectionImageObject` on PlayerGui and on every component,
  so the engine never draws its ring.
- The focused object gets the `ui-focus-visible` tag only while navigating with
  keyboard or gamepad, and a base rule draws a themed UIStroke ring (`$Ring`).
  Text inputs show the ring whenever focused, like shadcn.
- Base rules zero `BorderSizePixel` on every Gui class and turn off
  `AutoButtonColor` inside linked guis.

Navigation:

- Focus scopes: screens, modal scenes and open dialogs push a scope; Tab,
  Shift+Tab and arrows move through selectables in reading order inside the top
  scope; Enter/Space activate. Dialog content is a SelectionGroup with
  `SelectionBehavior = Stop` so the gamepad cannot leave it.
- Picking up a gamepad (or pressing Tab) with nothing selected selects the top
  scope's `defaultFocus`.
- Escape / ButtonB call `app.input:back()`: newest back handler first (an open
  dialog closes), else the SceneManager pops or calls `onBack`.

Touch: density `touch` gives 44px targets; checkboxes and switches use the whole
row as the hit area.

## Consequences

- No engine focus visuals anywhere in Lucy guis.
- Keyboard Enter may reach a button twice (engine plus InputManager); Button
  ignores a second click within 50ms.
- Hover styles can stick after a tap on touch screens (engine `:Hover` state).
  Acceptable for now; revisit with a touch-only StyleQuery.
