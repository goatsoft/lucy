# 0005: SceneManager with one ScreenGui per scene

- Status: accepted
- Date: 2026-10-30

## Context

Roblox has no UI scene concept. Every ScreenGui under PlayerGui renders at once,
ordered by DisplayOrder, and anything Enabled keeps taking input. A title screen
and the game HUD therefore fight unless something owns which is shown.

## Decision

- Each scene owns exactly one ScreenGui (`ResetOnSpawn = false`,
  `IgnoreGuiInset = true`), built lazily on first visit.
- Layers: `screen` (exactly one shown, DisplayOrder 10), `overlay` (shown
  independently, 100+, e.g. HUD), `modal` (stacked, 200+, with an input blocker).
  Shared portals for dialogs (900) and toasts (1000) sit above all scenes.
- Navigation is state: `scenes.current`, `scenes.stack`, `scenes.visible`. The
  manager reconciles enabled guis from state; `goTo / push / pop / show / hide`
  just write those paths. Exits run before enters.
- `keepAlive = false` destroys a scene's gui on exit (big screens visited once).
- Screens and modals push an input focus scope (ADR 0007); `back()` pops the top
  of the stack, else calls the screen's `onBack`.

## Consequences

- Title, lobby, game and menus can never overlap or steal each other's input.
- Saving `scenes.current` restores where the player was.
- Scenes are not tied to Roblox `Workspace` content; camera and world changes are
  the game's job in `enter`/`exit`.
