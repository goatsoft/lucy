# 0053: A named colour is compiled only for the rules it colours

- Status: accepted
- Date: 2026-11-19
- Amends: 0052 (named colours, and its note that rule count costs nothing per frame)

## Context

ADR 0052 compiles a rule written in `$Color` once with Primary's tokens and once per named colour,
with `.ui-color-<name>` on its first compound, because a Roblox token cannot be scoped below a
ScreenGui. Every colour gets a copy of every such rule, whether or not that colour is ever put on
what the rule styles.

Measured in Dance Lab (Studio, Mac, 2026-11-19), after the club and its main panels had opened:

- The sheets hold 4,904 rules; 3,572 of them are colour copies (38 colours). Only 277 of the
  copies match an element that exists; counted by group, the copies of the groups each colour is
  actually used with come to about 1,090.
- The DJ Booth's first open holds one frame for 112 ms. Its build is 5 ms of Luau; with the style
  links taken off it is 24 ms, and a second open is 17 ms. The rest is the engine styling 147 new
  instances against the rules.
- Taking out the game layer (2,769 rules) brings that first open to 67 ms; the pseudo-instance
  rules (855) to 92 ms. (Taking out the unused copies after other panels had opened gave 27 ms,
  but those panels had styled most of the booth's elements already: styling is cached once done,
  so only a cold first open measures it.)

So ADR 0052's note that restyling does not get dearer with more rules held for retagging existing
frames under throttled Studio frames; styling new instances, which is what a panel's first open
does, does get dearer, and the copies a colour never uses are most of that cost. A synthetic sheet
of 4,000 rules on one tag, or 60 derived sheets, cost only 6 to 11 ms on 150 new frames: what
Lucy's colour copies add is many rules on the tags its elements carry (`ui-text`, `ui-colored`,
`ui-button`...), each in 38 colours.

## Decision

A named colour may say which groups of rules it colours:

```luau
colors = {
    hype = "$Yellow400",                                           -- every group, as before
    ["genre-house"] = { "$Orange500", on = { "danceLabTones" } }, -- only these groups
}
```

- A group is what rules are added under: a component's rules (`Component.define`, its `ruleKey`
  or `kind`: `button`, `badge`, `progress`...), a `Theme.declare` key, or a game's
  `theme:addRules(key, ...)` key.
- A colour with `on` gets copies only of the `$Color` rules in those groups. Primary's copy (where
  no colour is set) and a scoped rule with no `$Color` (one copy on `ui-colored`) are unchanged.
- A colour without `on` keeps a copy of every `$Color` rule, so a game that names no groups works
  as before; it narrows its colours when it wants the speed.
- `theme:uncoveredColors(root)` lists every coloured element under `root` that a group's `$Color`
  rule would style if its colour listed that group: a check for Studio and specs, since a missing
  group shows as Primary rather than as an error. Lucy does not run it by itself (the colouring
  code has no theme, and walking the tree on every colour change would cost what this ADR saves).

## Consequences

- A game declares, once, where each colour is used. Dance Lab's 38 colours drop from 3,572 copies
  to 1,330, and its rules from 4,904 to 2,655. Cold first opens, two Play sessions each, without
  and with: DJ Booth 114/114 to 76/89 ms, The Lab 165/162 to 114/115, Inventory 231/209 to
  138/139, Dances 231/228 to 144/178, Settings 55/40 to 34/33 (Studio, Mac, 2026-11-19). The
  rest of each first open is the engine styling the elements themselves.
- A colour put on a group it does not list shows Primary's look there. `uncoveredColors` finds it;
  a game checks every screen with it when it narrows a colour.
- Start-up builds fewer rules (ADR 0052: building costs in proportion to a sheet's size).
- Group keys become part of a game's theme: renaming a group means updating the colours that
  list it. Lucy's component group names are its component kinds and stay stable.

## Where the rest of a first open goes

Measured in Dance Lab after this decision (Studio, Mac, 2026-11-19, Studio's window in front;
cold first opens, a fresh Play session each, the baseline repeated three times within 3 ms):
DJ Booth 72, The Lab 131, Inventory 123, Dances 138, Settings 33, Club Pass 180, Leaderboards
34 ms.

- With every rule taken out the same opens are 24, 67, 44, 49 and 19 ms. Rules are about half of
  a big panel's first open; the rest is building, laying out and styling what it shows.
- Each kind of rule costs about the same, about 0.025 ms per rule on a big panel's cold open:
  the 897 rules on tags no element carried in a full tour, the 482 pseudo-instance rules and the
  602 descendant (`>>`) rules each save in line with their count. Rules whose own tag nothing
  carries are cheaper: the 147 copies of the unused `link` button variant saved 2 to 4 ms.
- Dance Lab's tabs already build only when shown, and most of what a panel builds is on screen
  (DJ Booth 70 of 98 GuiObjects, The Lab 278 of 319, Club Pass 919 of 975).
- 500 of the 1,330 colour copies match no coloured element in a full tour (title, every panel and
  tab, welcome, practice; colours the tour never showed kept every copy). Taking them out saved
  8 to 15 ms on each big panel (Club Pass 180 to 167), about 10%.

So narrowing colours below groups is not worth an API and a game's declarations, and what is left
of a first open is the cost of what the panel shows. If a phone needs more, the next step is
spreading a big panel's build over a few frames, which changes how it appears.

Studio throttles to about 15 fps when its window is not in front, and a first open under 68 ms is
then hidden in an ordinary frame: check that an idle second has about 60 frames before measuring.

## Alternatives considered

- **Compile a colour's copies the first time it is used.** Adds rules while a game runs, which
  ADR 0052 ended, and moves the cost into the first open this ADR is about.
- **Record which colour and group pairs a play session used, and build only those.** A screen
  the recording missed would lose its colours with no warning.
- **Declare by component, MUI's way (`button = { "hype", "groove" }`).** Equivalent; a colour's
  own entry keeps everything about a colour in one place, as its value and shades already are.
- **Name tags instead of groups.** Finer, but a game would have to know Lucy's internal tags;
  groups are what a game already names when it adds rules.
- **Narrow a colour by variant as well as group (`on = { "button.outline" }`).** Measured above:
  about 10% of a big panel's first open, not worth a game declaring every variant it colours.
