# 0041: Effect textures

- Status: proposed
- Date: 2026-11-09

## Context

The first `rays` effect (ADR 0039) drew each ray with frames: flat bars, then
pointed wedges cut by a UIGradient. Next to a level up they read as paper cut
outs: light is soft, bright at its source and fading to nothing, and Roblox UI
has no shaders or additive blending to fake that. A soft image does it well and
cheaply.

## Decision

- Lucy ships a small set of **effect textures**: white, with all their shape in
  the alpha, so code tints them with ImageColor3 and stretches them freely. They
  are made by a script (`assets/effects/make.py`, so they can be remade or
  extended), uploaded once to the GOATsoft group, and listed in
  `Components/Effects/Textures` (`Lucy.Effect.textures`).
- The first two: `streak` (one ray, widest and brightest at its base, fading to
  a point) and `glow` (round, hot in the middle, falling off to nothing).
- The images are brushes, not pictures: a type still decides counts, sizes,
  angles, colours and motion in code, so effects stay procedural and themed.
- `rays` is rebuilt on them: a glow with a white hot centre, layers of streaks
  (long faint ones at the back, a white four point glint at the front), and a
  gleam (a slight swell and per ray flares), with `layers`, `core` and `pulse`
  options.

## Consequences

- Effects look like light, and cost one ImageLabel per ray instead of two cut
  frames.
- Lucy now depends on uploaded images (as it does for its icon sheet): a game
  sees them only once they load, and the ids must stay public.
- A glow reaches past its effect's square, so callers give it room (no clipping
  CanvasGroup right at the edge).
