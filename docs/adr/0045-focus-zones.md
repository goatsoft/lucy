# 0045: Focus zones, stepping into a HUD group with a key

- Status: accepted (JB, 2026-11-12)
- Date: 2026-11-12

## Context

Some controls on a screen must not hold the gamepad's selection while the player
plays: a HUD card at the top of the screen, a column of cheer buttons beside the
stage. While anything is selected, the left stick moves the selection instead of
the character. So nothing is selected, and the player steps in with a key when
they want those controls: D-pad up onto the card, D-pad up or down into the
cheers. Once in, the D-pad moves between the zone's controls, A presses and B
steps back out, leaving nothing selected so the stick walks again.

Dance Lab built this twice in game code, once for its player card and once for
its cheers: an action set for the entry keys, switched off whenever something
was selected or a menu was open; a search for the first or last button; a
`focusRef` check for "is focus in here"; and a back handler that cleared the
selection. Nothing kept the D-pad inside the group, so a press past its edge
left it for whatever was nearest. It is the same idea as a tile (ADR 0044),
entered from nothing selected instead of from the row, and Lucy should own it.

## Decision

`Lucy.useFocusZone(app, root, options)` is a composable:

- **Keys**: `options.keys` maps each key to where focus lands, `"first"`,
  `"last"` (reading order, `InputManager.selectables`) or a function given the
  list. They are an action set named `zone:<name>` (`options.name`, unique in the
  app), sinking, on only while stepping in is allowed: `options.enabled` is true,
  nothing is selected and no modal is open. Otherwise the keys reach whatever else
  binds them (a menu's own D-pad navigation, another zone).
- **Inside**: the root becomes a `SelectionGroup` with every `SelectionBehavior*`
  set to Stop (the engine's trap, as a modal Dialog and an open tile use), and a
  focus scope is pushed with `returnFocus = false`, so keys and Tab stay inside
  and nothing is selected when it pops.
- **Out**: B or Backspace (a back handler, on while focus is in the zone), or
  focus moving anywhere else (a click, a panel opening, the zone hidden and its
  focus dropped by `dropHidden`). The root's selection properties go back to what
  they were.
- It returns `{ inside, enter, leave }`: `inside()` is tracked, for bindings (a
  hint that shows while the player is in the zone); `enter(where?)` and `leave()`
  for anything else that should step in or out.

## Alternatives

- **A prop on Panel or Stack** (`focus = "zone"`). The zones so far are a
  component the game built (a card) and a game-made frame of buttons; a
  composable works on any root without changing the component, as
  `useFocusScope` does.
- **Leaving the D-pad free to leave the zone.** That is how the hand-built
  versions behaved; a press past the edge landed on whatever was nearest on the
  screen, which the player had not chosen. B is the one way out, as for a tile.

## Consequences

- Dance Lab's card and cheers become a few lines each, and any HUD group gets
  the same behaviour.
- One action set per zone, kept for the app's life (sets are not removed);
  defining the same name again reuses it.
