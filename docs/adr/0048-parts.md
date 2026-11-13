# 0048: Input follows the component tree (Core/Parts)

- Status: accepted (2026-11-14)
- Date: 2026-11-14

## Context

Lucy's input walks up from the focused object to find the component that takes
LB / RB (Tabs), the arrows (Slider, NumberField) or a press on one of its parts.
It walked the Instance tree. A part a game places outside its component's frame
left its component behind: Dance Lab puts every panel's `tabs.bar` in the
Sheet's header (tabs first, as the docs suggest), so with focus on a tab LB and
RB found nothing; they worked only once focus was in a panel. JB found it on a
controller (2026-11-14).

The first fix (6e7c2bf) gave the bar a `LucyShoulder` attribute that only the
LB / RB walk read. It worked, but it was one rule for one case: a nudge or a
press on a part placed apart would have had the same blind spot.

## Decision

A component can own a part wherever the part is placed, and Lucy's input goes up
the component tree, as a portal does elsewhere:

- `Core/Parts`: `Parts.own(handle, part)` marks the part as the component's (its
  `LucyOwner` attribute, the owner's id, as `LucyId` names a component's root);
  `Parts.parent(app, node)` is the next one up: the owner's root for an owned
  part while the owner is there, else `node.Parent`.
- InputManager's three walks (shoulder, nudge, press) and Devtools' component
  tree go up with `Parts.parent`.
- Tabs owns its bar. Nothing else changes for a game: passing `tabs.bar` to a
  header just works.

Visibility, layout and the overlay still follow the Instance tree: a part shows
where it is placed.

## Consequences

- Any component with a part a game may place apart (a bar, a toolbar, hints)
  calls `Parts.own` and its input keeps working there.
- Code that walks up for input must use `Parts.parent`, not `.Parent`; a new
  walk that forgets it brings the bug back for that walk.

## Alternatives considered

- **Sheet and Dialog take the tabs** (`Sheet.new({ tabs = tabs })`), placing the
  bar and keeping the link: fixes only those two hosts.
- **The one-off attribute** (6e7c2bf): replaced by this.
