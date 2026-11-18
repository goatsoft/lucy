/**
 * Lucy's palette, read from src/Core/Palette.luau at build time, so the docs always show the colours
 * Lucy ships. Each shade becomes sRGB the way Lucy's Oklab does it (clip, Oklab.gamut's default),
 * so a swatch is the colour a game gets in Roblox, not what a wide-gamut screen makes of OKLCH.
 */
import source from '~/src/Core/Palette.luau?raw'

export interface Shade {
  shade: number
  /** The token: `Violet500` */
  token: string
  /** sRGB, as Roblox shows it: `#8e51ff` */
  hex: string
  oklch: [number, number, number]
}

export interface Hue {
  name: string
  shades: Shade[]
}

function toGamma(c: number): number {
  return c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055
}

function channel(c: number): string {
  const clamped = Math.min(1, Math.max(0, toGamma(Math.min(1, Math.max(0, c)))))
  return Math.round(clamped * 255).toString(16).padStart(2, '0')
}

/** Oklab.oklchToRgb with gamut "clip", as a hex string. */
export function oklchToHex(L: number, C: number, H: number): string {
  if (L >= 1) return '#ffffff'
  if (L <= 0) return '#000000'
  const h = (H * Math.PI) / 180
  const a = C * Math.cos(h)
  const b = C * Math.sin(h)
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3
  const r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
  const g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
  const bl = -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s
  return `#${channel(r)}${channel(g)}${channel(bl)}`
}

function tokenOf(hue: string, shade: number): string {
  return `${hue[0]!.toUpperCase()}${hue.slice(1)}${shade}`
}

/** Every hue in Palette.hues order, each with its shades, lightest first. */
export function readPalette(text: string = source): Hue[] {
  const values = new Map<string, Shade[]>()
  const block = /^\t(\w+) = \{\n([\s\S]*?)^\t\},/gm
  for (const [, name, body] of text.matchAll(block)) {
    const shades: Shade[] = []
    for (const [, shade, L, C, H] of body!.matchAll(/\[(\d+)\] = \{ ([\d.]+), ([\d.]+), ([\d.]+) \}/g)) {
      const oklch: [number, number, number] = [Number(L), Number(C), Number(H)]
      shades.push({ shade: Number(shade), token: tokenOf(name!, Number(shade)), hex: oklchToHex(...oklch), oklch })
    }
    values.set(name!, shades.sort((x, y) => x.shade - y.shade))
  }
  const order = /Palette\.hues = \{([\s\S]*?)\}/.exec(text)?.[1]?.match(/"(\w+)"/g)?.map((q) => q.slice(1, -1)) ?? []
  return order.flatMap((name) => {
    const shades = values.get(name)
    return shades ? [{ name, shades }] : []
  })
}

export const palette: Hue[] = readPalette()
