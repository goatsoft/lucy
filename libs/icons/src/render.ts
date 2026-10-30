import { createHash } from 'node:crypto'
import { createRequire } from 'node:module'
import { getIconData, iconToSVG } from '@iconify/utils'
import type { IconifyJSON } from '@iconify/types'
import type { Layout } from './layout.ts'
import { slot } from './layout.ts'

// The renderer is a native module; load it with require so a broken install
// fails with a clear message only when rendering.
const require = createRequire(import.meta.url)

export interface Drawn {
  name: string
  /** viewBox of the icon */
  viewBox: string
  /** SVG body, ids made unique, one colour icons painted white */
  body: string
  /** false for icons that keep their own colours */
  tint: boolean
}

/**
 * Gives every id in `body` the prefix, and every reference to it. Deterministic,
 * unlike a random suffix, so the same icons always make the same sheet.
 */
export function prefixIds(body: string, prefix: string): string {
  const ids = [...body.matchAll(/\sid="([^"]+)"/g)].map(m => m[1] as string)
  if (ids.length === 0) return body
  const escape = (id: string) => id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  let out = body
  for (const id of new Set(ids)) {
    const e = escape(id)
    out = out
      .replace(new RegExp(`(\\sid=")${e}"`, 'g'), `$1${prefix}${id}"`)
      .replace(new RegExp(`url\\(#${e}\\)`, 'g'), `url(#${prefix}${id})`)
      .replace(new RegExp(`(href=")#${e}"`, 'g'), `$1#${prefix}${id}"`)
  }
  return out
}

/** One icon as SVG, ready to place in a sheet. Undefined when the set has no such icon. */
export function draw(set: IconifyJSON, name: string, index: number, palette: boolean): Drawn | undefined {
  const icon = name.slice(name.indexOf(':') + 1)
  const data = getIconData(set, icon)
  if (!data) return undefined
  const svg = iconToSVG(data)
  // Ids (gradients, masks) must be unique once icons share one SVG.
  let body = prefixIds(svg.body, `i${index}_`)
  if (!palette) {
    // Painted white, so ImageColor3 can tint it any colour.
    body = body.replaceAll('currentColor', '#ffffff')
  }
  return { name, viewBox: svg.attributes.viewBox, body, tint: !palette }
}

/** The SVG for one sheet holding `icons` at their slots (`indexes` are slot numbers). */
export function sheetSvg(icons: { drawn: Drawn; index: number }[], layout: Layout): string {
  const parts = icons.map(({ drawn, index }) => {
    const at = slot(index, layout)
    return `<svg x="${at.x}" y="${at.y}" width="${layout.size}" height="${layout.size}" viewBox="${drawn.viewBox}">${drawn.body}</svg>`
  })
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${layout.sheet}" height="${layout.sheet}">${parts.join('')}</svg>`
}

export function renderPng(svg: string): Buffer {
  const { Resvg } = require('@resvg/resvg-js') as typeof import('@resvg/resvg-js')
  return new Resvg(svg, { fitTo: { mode: 'original' }, font: { loadSystemFonts: false } }).render().asPng()
}

export function hash(data: Buffer): string {
  return createHash('sha256').update(data).digest('hex').slice(0, 32)
}
