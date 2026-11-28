# ADR 0062: Dock edges, pins, fitting and kept UI

- **Status:** Accepted
- **Date:** 2026-11-28
- **Amends:** ADR 0061 (docked sheets)

## Context

ADR 0061 made a dock: sheets that open side by side from one edge, the newest at the edge
pushing the others in. Two games now lean on it and found its limits (JB, 2026-11-28):

- Crime Spree's Menu wants its sub-sheets (Settings, Help, Leaderboards) to open beside the
  Menu, not push it in. `dockAppend` (03a93f1) did that with a flag on the new sheet, but it
  only stacks inward from the one edge: a sheet cannot open on the other side of the screen.
- Crime Spree's loot screen (inventory beside a car's boot or a stash) is 850 to 942 px wide at
  its natural size. A landscape phone has about 844 px, and the dock was capped at 90% of it with
  every sheet at full width, so the older sheet ran off the screen.
- Looting is modal (no running round with a bag open, like Tarkov), but the player can still be
  shot while looking, so their health must show above the dock's backdrop.
- Two docks (the Menu on the left, loot on the right) could both be open at once, each with its
  own backdrop and focus scope.

## Decision

1. **Each sheet picks its edge.** A sheet's `side` (left or right) is the edge it docks to, per
   sheet, not per dock. A dock has a row at each edge. Both rows share the dock's one overlay:
   one backdrop, one modal focus scope (the gamepad moves between edges), counted once. A press
   between the rows is outside and closes the dock, as any press outside it does.
2. **`dockPin = true` holds a sheet at its edge.** Sheets opened after a pinned sheet on the same
   edge open inward beside it. Unpinned sheets keep ADR 0061's order: the newest at the edge,
   pushing the others in. Pinned sheets keep the order they opened in, nearest the edge first,
   and always sit outside the unpinned ones. `dockAppend` is removed: the sheet that stays put is
   the one that says so (the Menu gets `dockPin`; its sub-sheets need nothing). `dockSlide` stays.
3. **One modal dock at a time.** Opening a sheet in one dock closes every sheet in the others.
4. **The room** a dock has is the viewport less the device safe area (notch, rounded corners) on
   each side. Both rows together never take more than that; the old 90% cap is gone, since a
   modal dock covers the game anyway and the space is better used.
5. **Fitting.** While every open sheet fits at its `width`, nothing changes. When they do not,
   sheets give way, unpinned before pinned and the oldest first, each down to its `minWidth`
   (a Sheet prop; the default is its `width`, so a sheet that says nothing never shrinks). A
   sheet narrower than its `width` keeps its content at full width and scrolls it sideways (its
   body becomes a `both` ScrollArea). If even every `minWidth` does not fit, each sheet takes its
   share of the room in proportion to its `minWidth` and scrolls, and Lucy warns once in Studio.
   Height already scrolls in a sheet's body.
6. **Nothing is scaled down.** Docks never shrink their content with a UIScale: a cell or button
   sized for touch keeps its size, and space is found by scrolling, never by making targets
   smaller.
7. **Kept UI.** A game marks a frame that must stay seen during any modal overlay with
   `app:keep(frame)`: it is moved into the `kept` portal (display order 920, above `modal` 900
   and below `tour` and `toast`) while any modal overlay is open, and back after. It takes no
   presses there (presses go to what is under it). Its rectangle is a reserved zone: a docked
   sheet that it overlaps at the top or bottom edge of the screen stops short of it (the dock's
   `maxHeight` and top inset leave its room), so the sheet's own content is never hidden under it.
   `app:keep` returns a function that stops it.
8. **Dragging near an edge scrolls.** `Scroll.edge(frame, point, dt)` scrolls the ScrollingFrame
   under `point` (screen pixels) toward any edge it is within `Scroll.edgeZone` (32 px) of, faster
   nearer the edge, and returns whether it moved. A game's drag and drop calls it every frame
   while something is held, so an item can be carried to a part of a sheet that is scrolled out
   of view.

## Consequences

- A sub-sheet opening beside a menu, a sheet on the far side of the screen and the newest pushing
  the rest in are all one model: an edge per sheet, and a pin on the ones that stay.
- A game sizes a sheet for a desktop (`width`) and says how small it may go (`minWidth`); the
  dock does the rest on a phone. Crime Spree's inventory also changes its own layout on a short
  screen (its equipment above the bag) to be narrower; that is the game's choice, not the dock's.
- Kept UI is the one way something draws over a modal backdrop. Toasts and the tour keep their
  own portals above it.
- Breaking: `dockAppend` is gone. Crime Spree's Menu is the only user and is moved over in the
  same change.
