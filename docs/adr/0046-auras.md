# 0046: Auras, effects worn in the world

- Status: accepted (2026-11-12)
- Date: 2026-11-12

## Context

Games dress characters in effects: a glow that grows with a player's rank, wings
bought for half an hour, a golden shimmer while a legendary dance plays, sparks
round whoever is on a streak. Dance Lab needs all four (rank auras, the dealers'
raven and bat wings, the Headliner gold, its streak aura) and Turf Heist will
want its own. Each is a little 3D picture worn on a character or set at a
point, and each needs the same plumbing:

- mounting on a character (attachments, welds, a rig for moving parts) and
  coming back after a respawn or an outfit change;
- every client seeing who wears what, players and bots alike;
- an opening when it is put on, a loop while it is worn, a close when it is
  taken off;
- a budget: with 20 or more characters in view, far auras fade and the
  farthest stop, as nameplates do;
- reduced motion and the game's quality setting;
- hiding on request (a game may hide auras on its stage or in a cutscene);
- nothing left behind on death, removal or the App's end;
- games add their own kinds without forking Lucy.

ADR 0039 solved the same shape for flat effects in the UI: one base with the
plumbing, types that only draw. ADR 0033 made Lucy a framework with a server
half, not only a UI library, so effects in the world belong here too.

## Decision

`Lucy.Aura`, the world sibling of `Lucy.Effect`. One base with the plumbing,
**aura types** that only build and animate.

- **A type** is registered by name: `Aura.register(name, { intro, loop, outro,
  defaults, build })`. `build(ctx)` makes the parts, emitters, beams and lights
  once, on `ctx.root` (a model parented to the character, or to a point), and
  binds them to the context's sources: `ctx.intro()`, `ctx.elapsed()`,
  `ctx.outro()`, `ctx.option(name)`, `ctx.strength()` (0 to 1, from distance and
  the budget) and `ctx.character`. A type with moving parts (wings) brings a
  rig and its animations as an asset and plays them through `ctx.animate(id)`.
- **The base (Core/Aura)** owns: mounting (character attachments by name, or a
  world position), remounting on respawn, the one frame driver on
  `Animate.drive`, distance fading and the budget (a cap on running auras,
  nearest first), reduced motion (opening jumps to its end, loops hold still,
  particles thin out), the `hidden` flag games set, and cleanup on the
  character's or App's maid.
- **Who wears what lives in the store**, on the server half (ADR 0033):
  `shared.auras.<u<UserId> or bot id>.<type>` is `{ options, untilTime }`, one
  entry per type (wearing a type again replaces it), so every App reads it at
  `server.auras`. The server writes it (`Aura.wear`, `Aura.take`); every App
  draws it (`Aura.follow`). A timed aura ends itself when
  `untilTime` passes, so a game only sets it once.
- **Players are `u<UserId>`** (amended 2026-11-13), as `Server.playerKey`:
  `wear` and `take` take a Player or a UserId and key it that way
  (`Aura.idOf`), and refuse an id of digits alone or with a dot. A bare
  UserId was an array index in the store and came back to the client as
  text, so taking an aura off never reached the client (found in Dance Lab).
- **Nothing about why.** Ranks, purchases, timers that pause while a player is
  away, XP bonuses: the game decides and writes the store. Lucy only draws.
- **Built in:** `glow` (a soft halo with rising sparks, in theme tones), so the
  base has one tested type. Games register the rest.

## Consequences

- Dance Lab registers `rankGlow`, `ravenWings`, `batWings`, `headlinerGold` and
  moves `StreakAura` onto the base (a point aura at the stage). Its rules
  (ranks, the dealers' 15/30/60 minute auras, karma or Robux, the 10x XP cap,
  clocks that stop while a player is away) stay in the game.
- One budget and one fade for every aura, so 20 dancers with wings cost what
  the budget says, not what each type happens to do.
- Docs: an "Auras" page with a preview of `glow`, and a recipe for a timed
  aura bought from a shop.

## Alternatives considered

- **Each game builds its own.** Rejected: the mounting, budget, motion and
  cleanup are the same in every game, and getting them wrong costs frame rate.
- **Fold auras into `Lucy.Effect`.** Rejected: an Effect is a square stage in a
  gui; an aura is parts in the world on a character. They share the shape of
  the API (register, intro, loop, reduced motion), not the plumbing.
- **Server-made aura instances, replicated.** Rejected: every client would pay
  for every aura at full cost; the client fades and budgets what it sees.
