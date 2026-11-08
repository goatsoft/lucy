# 0039: Effects

- Status: proposed
- Date: 2026-11-09

## Context

Games celebrate: a reward lands, the player levels up, a prize is opened. Dance
Lab's rehearsal reward wants a sunburst of rays behind the potion, and its
level up and battle pass rewards will want the same and more: sparkles, a
glow, confetti, a shine across a card. Each is a little animated picture behind
or over something else, and each needs the same plumbing:

- a box to fill, usually a square centred on the thing it celebrates;
- an opening that plays when it is shown, and again on demand (the moment a
  reward lands);
- some keep moving after the opening (rays turn), some settle and stop;
- nothing runs while hidden, everything stops on destroy;
- reduced motion: the picture is simply there, still;
- colours from the theme, in a few tones;
- games add their own kinds without forking Lucy.

A first cut made the rays their own component (`Lucy.Rays`) with all of that
inside it. A second kind would have copied the plumbing.

## Decision

One component, `Lucy.Effect`, with the plumbing, and **effect types** that only
draw. `Lucy.Effect.new({ type = "rays", ... })`.

- **The base (Components/Effect)** owns: the square stage centred in the box
  (`size`), `visible`, `variant` (`primary`, `warning`, `success`,
  `foreground`), the tags (`ui-effect`, `ui-effect-<type>`,
  `ui-effect-<variant>`), `effect:play()`, the one frame driver on
  `Animate.drive` (Core/Animate), reduced motion and cleanup. `effect.running`
  says whether it is animating.
- **A type** is a definition registered by name:
  `Effect.register(name, { intro, loop, defaults, rules, render })`.
  `render(ctx)` builds the picture once, binding it to the context's sources:
  `ctx.intro()` seconds into the opening (it stops at `intro`),
  `ctx.elapsed()` seconds running (advances only for a `loop` type),
  `ctx.variant()`, `ctx.option(name)` (the type's props over its `defaults`),
  and `ctx.handle` to expose parts. The type's `rules` are its looks, by
  `$Token`, added once like a component's.
- **Built in:** `rays` (Components/Effects/Rays): rays that fan out from the
  middle and turn. Games register their own the same way.
- **Reduced motion:** the base jumps the opening to its end and never advances
  `elapsed`, so every type is still without code of its own.

Types draw declaratively (ADR 0018): their instances bind to the context's
refs; the base's driver is the only thing that ticks.

## Consequences

- New celebrations are a small file that only draws; the timing, visibility,
  motion preference and teardown are tested once, in the base.
- `Lucy.Rays` is not public; it never shipped.
- A type cannot change the base's lifecycle (its own timers would bypass reduced
  motion and hiding). If one needs more than an opening and a loop, the base
  grows a hook for it.
