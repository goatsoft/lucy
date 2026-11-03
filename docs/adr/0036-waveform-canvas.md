# 0036: Waveform draws on a canvas, with Frames as the fallback

- Status: proposed
- Date: 2026-11-04

## Context

A song's waveform wants many columns (a 3 minute song at 4 levels a second is
720 values) and, for the dots and blocks looks, many cells in each. Drawn with a
Frame per cell that is thousands of instances for one picture, and each
progress step repaints them all. Roblox's `EditableImage` draws the same picture
into one image, but a device may refuse one: each client has a memory budget for
them, and a live game needs "Allow Mesh / Image APIs" turned on. Lucy so far draws
everything with instances, so this is its first component on a canvas.

## Decision

- **`Lucy.Waveform` draws on two canvases** when it can: the dimmed columns and
  the lit ones, the lit one inside a clipping frame sized to the progress. The
  canvases are drawn again only when the levels, a colour, the theme or the size
  change; playing only resizes the clip. They are drawn at twice the screen
  resolution (at most 1024 pixels a side) so small dots stay round.
- **Refused, it draws with Frames**, averaged down to at most 64 columns and 12
  cells, so it costs a few hundred instances at worst. The looks match (colours,
  gradient, stops, fade, track, peaks); only the detail drops.
- **`renderer`** picks: `auto` (the default), `canvas` (never falls back) or
  `frames` (always Frames, for a game's low-effects setting). `handle.mode` says
  which is in use. The labels for the canvas exist from the first render, so the
  layout is the same before and after the first drawing.
- **Levels are a plain prop** (an array, a ref or a getter), not a state key,
  as with Table's rows: state merges arrays in place.
- **Specs swap `Waveform._createCanvas`** to test the fallback, and read canvas
  pixels to test the drawing.

## Consequences

- A long song previews at full detail with two images, and scrubbing is cheap.
- Games must turn on "Allow Mesh / Image APIs" before going live, or every
  player sees the Frames version. The docs say so.
- Two drawing paths to keep in step: each look is specced on both.
- Other components that draw many small shapes (charts, meters) can follow the
  same pattern.
