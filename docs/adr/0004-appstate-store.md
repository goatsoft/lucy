# 0004: One AppState store for all UI state

- Status: accepted; amended by 0017 (the store is a living tree, same API)
- Date: 2026-10-30

## Context

Games need to drive UI from anywhere: disable the Play button while matchmaking,
open the quit dialog from a keybind, switch theme from settings, read how many
toasts are up. Passing component references around does not scale.

## Decision

`AppState` is a synchronous, path-addressed, copy-on-write store owned by the App.

- Paths are dot strings: `ui.play.disabled`, `scenes.current`, `input.device`.
- `get / set / merge / update / remove / subscribe / batch / scope`.
- Copy-on-write means a value read earlier never changes, and "did this path
  change" is an identity check. Subscribers fire for their path, ancestors and
  descendants, only when the value at their path actually changed.
- `batch` coalesces to one notification per subscriber.
- A failing subscriber is reported and never stops the others.

Reserved roots: `ui.<id>` (components), `scenes`, `toasts`, `input`, `theme`,
`density`. Everything else is the game's.

## Consequences

- The app controls any component by id with no reference to it.
- State written before a component mounts wins over its props, so saved settings
  can be restored first.
- Synchronous notification keeps tests deterministic. Heavy work in a subscriber
  blocks the writer, so keep subscribers small.
