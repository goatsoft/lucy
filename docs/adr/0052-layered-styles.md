# 0052: Styles are declared up front, in layers; colours come from a palette

- Status: accepted
- Date: 2026-11-18
- Amends: 0003 (one Design sheet holding every rule, priority bands across Lucy and the game)

## Context

ADR 0003 puts every rule in one sheet, `Design`. Lucy adds a component's rules the first time a
component of that kind mounts (`Component.mount` calls `theme:addRules`), and a game adds its own
with `theme:addRules` once the App exists. Profiling Dance Lab's first MENU press in the club
(Studio, ScriptProfilerService, 2026-11-18) found two costs that come from this, not from building
instances:

1. **Rules added mid-game.** The first ToggleGroup, Select and SortButton of the session added
   their rules as the dance menu and the inventory were built: 17, 9.5 and 5 ms, 32 ms of the
   menu's 69, almost all of it `Instance.Parent` on the StyleRules.
2. **A sheet that only grows.** Dance Lab's `Design` held 3,391 rules, 2,012 of them its tone
   rules (`danceLabTones`: about 40 tones, each with about 50 rules, most of them
   `.dl-panel-<tone> >> .ui-...` overrides recolouring Lucy's components inside a toned panel).

It also hides a bug: two rules of equal Priority are ordered by when they were added, and that
depended on which component the player happened to open first.

### What the engine does

Roblox documents little of this, so each fact below says where it comes from. The facts marked
"tested" are pinned by Lucy specs (`Theme.spec`, "the engine"), so a change in Roblox fails the
suite instead of a game's look.

| Fact | Source |
| --- | --- |
| Tokens are attributes of a StyleSheet, used as `$Name` | docs (UI styling) |
| One StyleSheet applies to a tree, through a StyleLink on the ScreenGui | docs (UI styling) |
| Themes are swapped by pointing a StyleDerive at another theme sheet with the same tokens | docs (UI styling) |
| Higher Priority wins | docs (StyleRule), DevForum staff |
| At equal Priority the rule added later wins; there is no CSS specificity (`.a` added after `Frame.a` beats it) | DevForum staff (2025-07-30: the Style Editor now assigns lower default priorities to tag rules; scripts get no defaults), tested |
| A sheet's own rules beat every rule of a sheet it derives, whatever their Priority | tested |
| Of two StyleDerives on one sheet, the later one's rules win, whatever their Priority | tested |
| Layers merge per property: a lower layer's other properties still apply | tested |
| A rule reads tokens through its own sheet's derives, at any depth, aliases included; a token set on a deriving sheet does not reach a derived rule | tested |
| A token cannot be scoped below a ScreenGui: a StyleLink on an inner Frame, a token on a StyleRule and a token on an instance are all ignored | tested |
| Adding a rule costs in proportion to the rules already in that sheet (20 rules: 0.07 ms into an empty sheet, 1 ms at 1,000, 3.6 ms at 3,400, about 6 ms into a linked one), so building a sheet of n rules costs about n²; derived sheets add nothing (0.3 ms into a 50-rule sheet deriving 3,400) | tested |
| `SetStyleRules` replaces a sheet's whole list; given rules already in the sheet it empties it. Lucy never calls it | tested |

## Decision

### 1. Layers

Each layer is a sheet of its own, deriving the one below, so precedence is the layer and each
insert pays only for its own layer's size (Core/Theme):

    Values    derives the active Theme_<name> and Density_<name> (re-pointed to switch); no rules
    Lucy      Lucy's base rules and every component's rules
    Game      the game's rules
    Fixed     Lucy's rules for what a component is, not how it looks (`fixed = true`)
    Design    rules that come and go while the game runs (a setting switched on, say): the
              live layer, and the sheet linked to every gui

A game rule beats every Lucy look by its layer, with no Priority above Lucy's: the game sets its
look, as an app's CSS layers over a component library's. That includes focus: Lucy's ring is a
default the game may restyle (Dance Lab does, on its PLAY button and reward tiles). Priority
orders rules within a layer only.

Two of Lucy's rules are not looks but what a component is: an untinted icon keeps its picture's
own colours (ImageColor3 white), and a gradient's host is white under it so the gradient's colours
show. Moving Dance Lab's rules over Lucy's in a test session, these were the only real changes on
any screen (The Lab's and the Club Pass's panels went dark, the Karma coin went purple). Lucy had
kept them winning by repeating them at rising priorities (20, 90, 100, 201); they are now one rule
each, `fixed = true`, in the Fixed layer over the game's.

- `theme:addRules(key, rules)` from a game goes to `Game`; `{ layer = "live" }` puts rules that
  are added and removed while playing in the live layer, a small sheet, so it stays cheap.
- Within a layer, rules keep the order they were declared in (option (a) of the discussion), which
  is now fixed: a later rule wins a tie. Priority stays for genuine exceptions.

### 2. Declared up front

Rules are declarations, not effects of mounting:

- `Theme.declare(key, rules, options?)` records a group of rules when its module loads, in order.
  `Component.define(spec)` declares a spec's rules (Lucy's components define theirs at load).
- `Theme.new` builds the Lucy layer from every declaration made so far, before any gui exists, so
  nothing is added while a player plays. Lucy's own layer is about a thousand rules: some 16 ms,
  once, at start.
- A group first needed after start (a component a game defines later, a gradient or effect made
  for a name the game picks at run time) is added to its layer then, at that layer's cost.

### 3. Named colours, compiled by Lucy

(`Palette` is already Lucy's OKLCH hue scales, and `$Accent` shadcn's hover fill, so the concept
is `color`, as Radix and MUI name it.)

- **Shades.** A theme names its colours (`colors = { hype = "$Yellow400" }`). Each gets a token
  (`Hype`) and Lucy's generic shades, worked out as Primary's are: Hover, Foreground, Soft,
  MutedForeground (with MutedTint), Border, Shadow. A game adds its own by recipe
  (`colorRecipes = { Glow = function(colour, shade) ... end }`). Primary gets the same shades; a
  token the theme sets itself is kept.
- **Rules.** A rule written in `$Color...` is compiled in the layer it is added to: a copy in Primary's
  tokens for where no colour is set (unless `scoped = true`, for a look that belongs only inside a
  coloured container), then one copy per colour with `.ui-color-<name>` on its first compound,
  right after it so it wins a tie. A scoped rule with no `$Color` holds in any colour: one copy,
  on `.ui-colored`, which every coloured element also has. Lucy's components moved every
  `$Primary` in their rules to `$Color`, so everything that used Primary follows a colour; Ring
  (focus) is separate.
- **Scope.** Lucy builds children before their parents (`children = { Lucy.Button.new(...) }`),
  so a colour cannot follow creation (a Vue-style provide/inject would miss them): it follows
  the instance tree. `Lucy.color(container, name)` and a component's `color` prop make a coloured
  container (attribute LucyColor). It tags itself and every element in it that has a tag of its
  own as `ui-color-<name>` and `ui-colored`, as they arrive; the nearest coloured container wins,
  as a CSS variable does, and an element moved out loses it. Two listeners per coloured container
  (added, removing), none per element.

A game's toned panel is then `color = "premium"` on the Sheet, and the 2,012 rules Dance Lab
writes by hand become Lucy's to generate.

## Consequences

- Nothing styles itself into the sheet while a game runs, unless the game asks for a live rule.
- A game no longer needs Priorities above Lucy's to win; existing ones keep working, ordered
  within the game's layer.
- A game rule that relied on losing to a Lucy rule (Lucy's focus rules, Priority 100, over a
  game's 40 to 99) now wins and has to say its state itself, as CSS layers do: a game that
  recolours a stroke or a fill says what it looks like focused too. Moving a game is checked by
  comparing every styled property on each screen before and after.
- Equal-Priority ties no longer depend on the order screens were opened.
- Every component's rules exist from the start, even for kinds a game never shows: a bigger Lucy
  layer, paid once at start, never during play.
- Restyling does not get dearer with more rules or with `>>` selectors, as far as Studio shows:
  retagging 20,000 frames under 3,400 descendant rules, 3,400 compound rules or none left every
  frame within the throttled 67 ms (Studio, Mac, 2026-11-18). What the rule count costs is
  adding them: a game layer of 2,841 rules is about 125 ms of start-up by the curve above. So
  section 3 (the palette) is for how a game is written, not for frame time; still to be
  confirmed on a phone.

## Alternatives considered

- **Keep one sheet, add rules at start.** Ends the mid-game cost, but a game still needs priorities
  above Lucy's, and every rule added later pays for the whole sheet.
- **Lucy computes CSS specificity into Priority.** Gives the cascade CSS has, but adds a selector
  parser, and some rules' importance does not follow from their selector. Layers and declaration
  order cover what the games do.
- **Colours set from code, not rules.** Code-set properties beat every rule (0003), so hover,
  pressed and disabled would all move to Luau.
