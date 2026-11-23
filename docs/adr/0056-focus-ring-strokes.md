# 0056: The focus ring is strokes of its own

- Status: accepted
- Date: 2026-11-23
- Amends: 0007 (the ring's base rule)

## Context

The focus ring was a base rule on the focused element's own outline,
`.ui-focus-visible::UIStroke`, in Lucy's layer at priority 100. Since 0052 a game's rule beats
every Lucy rule whatever the priority, so any game rule on an element's `::UIStroke` hid the
ring. Dance Lab outlines its coloured cards that way (`.dl-tone::UIStroke`): on a controller its
potion, gear and admin rows showed no focus at all, and the player could not tell which row the
D-pad was on.

Even where it won, the ring only recoloured the element's outline, at much the same width. On a
card that already had a thick coloured outline it read as one more border, and in a colour close
to `$Ring` it barely changed at all.

JB (2026-11-23): fix it in Lucy so every game gets it; the ring must stay inside the edge (rings
drawn outside get clipped), and it should be a little soft, so it looks different from a border.

## Decision

- **The ring is three UIStrokes of InputManager's own**, put inside the focused element while
  the player navigates and taken away when focus leaves or the mouse is used: `ui-focus-ring`
  (sharp, `$FocusRing`), `ui-focus-feather` (`$FocusFeather`, see through) and `ui-focus-halo`
  (`$FocusHalo`, fainter), all tagged `ui-focus-ring-part`. A game's rules on the element's own
  `::UIStroke` never reach them, so a card keeps its outline and the ring shows over it.
- **All inside the edge** (`BorderStrokePosition.Inner`, a spec checks every one) and drawn above
  the element's own outline (the strokes' ZIndex).
- **Soft, not a border.** Roblox strokes cannot blur, so the softness is stacked strokes: the
  sharp ring at the edge, then the feather and the halo reaching further in, each fainter.
- **No ring of its own on a ring host** (`ui-ring-host`: Checkbox, Switch, RadioGroup, Menu,
  and now Slider, which rings its thumb), nor on UI Lucy did not build (its
  `SelectionImageObject` is not the app's blank image): `app.selectionRing` still rings that.
- The old base rule and the ring hosts' rule that hid it are gone. A game that recoloured the
  ring on one element moves its rule from `.its-tag.ui-focus-visible::UIStroke` to
  `.its-tag > .ui-focus-ring-part`.

## Consequences

- Focus shows on every Lucy element however a game outlines it.
- Three small instances are made each time focus moves while navigating, and destroyed when it
  moves on.
- Games with rules on `.ui-focus-visible::UIStroke` must move them (Dance Lab had three). Such a
  rule now styles the element's own outline while it has focus, which is still allowed.
- Part rings (`Component.partRing`) are still one sharp stroke; they can take the feather later.
