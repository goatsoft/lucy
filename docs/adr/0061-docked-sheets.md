# ADR 0061: Docked sheets

- **Status:** Accepted
- **Date:** 2026-11-28
- **Amended by:** ADR 0062 (an edge per sheet, pins, one dock at a time, fitting, kept UI)

## Context

Crime Spree's inventory (JB, 2026-11-28) is a container (a car's boot, a stash) beside the
player's own bag, the way looting games show them: the container opens at the car, and
opening the inventory slides it in from the edge of the screen and pushes the container over,
so things can be moved between the two. Two sheets on the same side overlapped, each had its
own backdrop over the other, and the focus scope of the newest kept the gamepad out of the
older one. Panels also appeared without sliding, although the Sheet page said they slide.

## Decision

1. **A Sheet takes `dock = "<name>"`.** Sheets with the same dock are laid out by
   `Core/Dock` in place of each having an overlay of its own.
2. **One overlay per dock**, made the first time a sheet joins it and kept for the app's life:
   one backdrop, one modal focus scope over a row that holds every docked sheet (so the gamepad
   moves between them), counted once in `overlay.modal`. It is open while any of its sheets is
   open or still sliding out.
3. **The newest is at the edge.** The row is a list aligned to the dock's edge (its first
   sheet's `side`), each sheet in a clipping holder ordered by when it opened. A sheet slides
   in by its holder growing from nothing to its width (a tween on a NumberValue), which pushes
   the others over in the same motion; closing slides it out and the others back. Reduced
   motion skips the slide. The overlay places the row at the full height of the screen, as
   wide as the holders, at most `Overlay.panelShare` of the screen.
4. **Back closes the newest**; a press outside closes them all (writing false to the dock's
   open, a writable computed). Focus moves to a newly opened sheet's default once it has slid
   in, and to the newest left when the focused one closes.
5. **Docked sheets are always panels**, on touch too: two drawers from the bottom cannot sit
   side by side.
6. Sheets without a dock are unchanged.

## Consequences

- A game gets the container-and-inventory pattern from two ordinary sheets and one name.
- The dock's overlay is never destroyed while the app lives; a sheet that is destroyed leaves
  the dock and the row places itself again.
