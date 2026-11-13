# 0047: The panel frame, an offset shadow and the title on the edge

- Status: accepted (2026-11-13)
- Date: 2026-11-13

## Context

Dance Lab is moving every dialog to a bolder look (JB, 2026-11-13): a thick
black border, a hard offset shadow in the screen's colour (as its logo and its
title screen's PLAY card have), and the title on a plate that pops out of the
panel's top edge. The plate frees the header row for tabs and controls: the Club
Pass board needed that room for REWARDS / CHALLENGES.

The border is already a look: themes set `.ui-dialog-content::UIStroke`. The
other two are not. A shadow drawn behind a panel cannot be a child of it (a
child always draws over its parent), and a title above the top edge sits outside
the panel's box, so the overlay has to make room for it. Neither can be done
from a game's theme, and doing them in each game means reaching into Dialog's
and Sheet's instances, which breaks when they change.

## Decision

Dialog and Sheet put their panel in a **frame**: a clear holder (`dialog.frame`,
`sheet.frame`) that the overlay places, with the panel (`.content`, unchanged:
every rule and tag on it still applies) inside, and two optional parts beside it.
One core piece builds it for both, `Core/PanelFrame`.

- **The shadow** (`ui-dialog-shadow`, `ui-sheet-shadow`) is a frame behind the
  panel, its size, offset by the `PanelShadow` token (pixels, right and down).
  It takes the panel's own corners, whatever rule set them (JB: not always
  rounded): a square side sheet has a square shadow.
  `PanelShadow` is 0 in Lucy's themes, so nothing changes for a game that does
  not ask; a theme sets it and colours the shadow with a rule.
- **The title on the edge**: `titlePlacement = "edge"` puts the title on a plate
  (`ui-dialog-plate` / `ui-sheet-plate`, with its own shadow) standing on the
  panel's top edge, coming down over it by the `PanelPlateOverlap` token. The
  frame keeps the room over the panel for it, and the body's height cap counts
  it. The title label keeps its tag (`ui-dialog-title`), so a title's look and
  `handle.titleLabel` work as before; the description stays in the header.
- **A game's default**: the `PanelTitleEdge` token (0 inside, 1 on the edge;
  tokens are numbers, colours and sizes only) is what a dialog or sheet uses
  when it does not say, so a game puts every title on the edge from its theme.
  `titlePlacement` on one panel wins.

Looks stay in rules: the shadow's colour, the plate's fill, corners and stroke.
Code only places the parts (the offset and the overlap are tokens it reads).

## Consequences

- One more instance level: the overlay places `frame`, not `content`: the frame
  is the focus scope and selection group, and carries the placement (anchor,
  size, the width cap). Tags and rules on `content` are unaffected; code that
  read the content's placement or parent reads the frame.
- A panel with a shadow is that many pixels wider and taller in the overlay, so a
  centred dialog sits half the offset up and left of where it did.
- On a sheet that fills the screen's height, the room for an edge title comes
  off the panel's top.
- Hand-built panels (a game's own scenes) can take the same look from the same
  core piece later; for now Dance Lab has its own (its `PopPanel`).
