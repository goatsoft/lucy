# 0013: Lucy the mascot, her assets, and Lucy's type

- Status: accepted
- Date: 2026-10-30

## Context

Lucy has a mascot: a girl with headphones in magenta, orchid, violet and sky.
The project needs app icons, favicons, a logo, social and Roblox images, and a
typeface that suits her and works in the game and on the website alike.

The supplied renders (`Lucy.webp`, `Lucy-Masthead.webp`) came out of background
removal with all of the black linework cut out: every outline pixel is fully
transparent. She looks right on black and washed out on anything light.

## Decision

- **Source of truth**: the two renders in `assets/brand/source`, plus
  `assets/brand/build.py`, which generates everything in `assets/brand/dist`
  and copies what the site needs (`--site`). Rerun it whenever the art changes.
- **Linework restored in the build**: holes inside the silhouette become ink, a
  morphological close first seals lines that run out to the edge, and a thin
  ink stroke goes round the outside. Every asset uses the restored art.
- **Assets**: rounded app icons (1024, 512, 192), maskable 512 with an 80% safe
  zone, apple-touch 180, favicons (16, 32, 48 and .ico, cropped tighter so the
  headband survives at 32 px), Roblox experience icon 512 and thumbnail
  1920x1080, a 1200x630 social image, logo lockups for dark and light grounds,
  and the wordmark as SVG paths (gradient, white, ink).
- **Vectors**: `lucy-portrait.svg` and `lucy-head.svg` are high-fidelity traces
  of the restored art (about 4 MB each): exact for print and large display, not
  for hand editing. The hand-drawn `Lucy.svg` was a looser likeness and is not
  used. Small sizes use the PNG/WebP exports.
- **Background**: night violet (`#2b0f57` to `#0e0822`) with a magenta glow and a
  sky glow behind her head, the colours sampled from the art.
- **Type**: **Fredoka** for display (wordmark, headings, panel and dialog
  titles) and **Nunito** for text. Both are SIL OFL Google Fonts *and* built
  into Roblox (`FredokaOne`, `Nunito` 200 to 900), so the game and the site
  match. In the kit, `FontDisplay` is FredokaOne and the `FontSans*` tokens are
  Nunito, each named weight one step heavier because Nunito has no 500 and sets
  lighter than Builder Sans.
- The `assets/` folder is never part of the Wally package (ADR 0012).

## Consequences

- One script rebuilds the whole identity; nothing is hand-exported.
- At 16 px a detailed face cannot survive; browsers on modern screens use the
  32 px favicon. A simplified 16 px glyph can be drawn later if needed.
- Games that prefer Builder Sans override `primitives.FontSans*` in `App.new`.
