# 0044: Tiles, one gamepad stop per row

- Status: accepted (JB, 2026-11-12)
- Date: 2026-11-12

## Context

A list whose rows hold several controls is slow on a gamepad: an inventory row
with WEAR and a button per colour, a potion with DRINK, a shop row with BUY and
PREVIEW. The engine's selection stops on every button, so the D-pad crawls down
a column of buttons and the list jumps about. Dance Lab worked round it twice in
game code: a table of "lines" its GEAR tab pointed `NextSelectionUp/Down` at on
every `SelectedObject` change, and later a `rowNav` helper doing the same for
POTIONS with left and right into each row. Both are the kind of navigation code
Lucy exists to keep out of games, and every new list would need it again.

## Decision

A tile is an Item with `focus = "tile"`. Its root is always a button and is the
only stop until the player steps in. Core/Tiles holds the behaviour; Item owns the
state.

- **Closed**: focus that lands on anything inside a closed tile goes to the tile.
  `InputManager.selectables` skips what is in a closed tile, so Tab, arrow keys,
  `defaultFocus` and the nearest-control fallbacks see the tile only. When focus
  lands on a closed tile, its `NextSelectionLeft/Right` point at its first control
  and its `NextSelectionUp/Down` at the nearest stop above and below (keys' order,
  tiles collapsed). The engine follows these on the D-pad, Lucy on the arrow keys.
- **Stepping in**: A or Enter on the tile (`click` while navigating), or the D-pad
  moving from the tile onto a control inside it. The tile sets `entered`; its root
  stops being selectable, becomes a `SelectionGroup` with every
  `SelectionBehavior*` set to Stop (the engine's trap, as a modal Dialog uses), and
  pushes a focus scope and a back handler.
- **Stepping out**: B or Backspace (the back handler), or focus moving anywhere
  outside the tile. The scope pops with the tile as `returnFocus`.
- **Mouse and touch** are untouched: the tile logic runs only while navigating, so
  a click on a control inside a closed tile reaches it.

`InputManager.markFocus` calls `Tiles.landed` after every focus change, the same
place the ring and scroll-into-view already hang off. The Item takes a `children`
slot under its text so a row's extra controls (a row of colours) sit inside the
tile and its ring.

## Alternatives

- **A list-level "rows" mode on Stack** that points each child's up and down at its
  neighbours. Not needed once tiles collapse: the nearest-stop search already goes
  row to row, and a Stack mode would not help lists built in a Grid or a Scroll
  Area. It may still be worth it for rows that are not Items.
- **Making a tile's controls non-selectable while closed.** They are the game's own
  components with their own `Selectable` bindings; redirecting focus that lands
  inside is simpler and leaves them alone.

## Consequences

- Games get row-by-row lists with one prop, and the skill tells agents never to set
  `NextSelection` or follow `SelectedObject` themselves.
- Every focus change does a short walk up the ancestors (`Tiles.closedAround`), and
  `selectables` does the same per candidate. Cheap next to the engine's own
  selection work.
- Only Item is a tile for now. A Pressable or Panel card could take the same prop
  later through Core/Tiles without changing it.
