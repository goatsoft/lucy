# 0010: Tailwind palette in OKLCH, converted with Oklab

- Status: accepted
- Date: 2026-10-30

## Context

Tailwind v4 and shadcn define colours in OKLCH. Roblox renders sRGB `Color3`.
Several Tailwind shades (blue-500, green-500, amber-500 ...) are outside sRGB.
shadcn also uses translucent values (dark border `white/10%`, hover
`primary/90`), but a Color3 has no alpha.

## Decision

- `Core/Palette.luau` is generated from Tailwind's `theme.css`:
  `lune run scripts/gen-palette https://raw.githubusercontent.com/tailwindlabs/tailwindcss/main/packages/tailwindcss/theme.css`
  gives 26 hues x 11 shades as `{ L, C, H }`. This ADR is the only place the
  upstream source is named; code and docs call it "the palette".
- `Core/Oklab.luau` converts OKLCH/Oklab to sRGB. Out-of-gamut colours are
  clipped by default, which reproduces Tailwind's published sRGB values exactly
  (red-500 `#fb2c36`, blue-500 `#2b7fff`); `Oklab.gamut = "chroma"` lowers chroma
  at constant lightness and hue instead.
- Every palette colour is a primitive token (`Zinc950`, `Blue500`).
- Semantic themes follow shadcn per base colour (`Tokens.themesFor("zinc")`,
  also slate, gray, neutral, stone, mauve, olive, mist, taupe) with an optional
  primary hue.
- Derived tokens: `Tokens.over(fg, bg, alpha)` composites in sRGB exactly as a
  browser does, so translucent shadcn values look identical (dark border
  `#222224`). `Tokens.mix(a, b, t)` is a perceptual Oklab mix for designer use.

## Consequences

- Colours match shadcn and Tailwind docs pixel for pixel in sRGB.
- `Oklab.mix / adjust / distance` are available to game code for tints,
  hover shades and colour pickers.
