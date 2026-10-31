/**
 * Pictures of docs examples. A page marks an example with a `<!-- preview -->`
 * line right above its ```luau block; a page can mark as many as it likes. The
 * code is rendered in Studio in the light and dark themes (Studio is needed, so
 * an agent or a person runs the render; see docs/development.md "Example
 * pictures").
 *
 * A marker can carry options:
 *
 *   <!-- preview -->                 drawn with others on one screen; the code gets
 *                                    `Lucy`, `app` and `parent`
 *   <!-- preview solo -->            drawn alone: it opens a dialog, a sheet, a toast
 *                                    or anything else that covers the screen
 *   <!-- preview screen -->          a whole client script (a recipe, the homepage),
 *                                    shown full screen
 *   <!-- preview then="..." -->      Luau run after the example (any kind), to go to
 *                                    a scene or open a menu first
 *
 * Names: the first marked example on docs/components/button.md is
 * components-button, the second components-button-2, and so on. The homepage's
 * example (apps/site/src/content/quickstart.md) is home-quickstart.
 *
 *   node scripts/doc-previews.ts list     print the marked examples as JSON
 *   node scripts/doc-previews.ts blocks   print every luau block, marked or not
 *   node scripts/doc-previews.ts serve    serve the marked examples to Studio's renderer
 *                                         (scripts/doc-pictures.luau) on 127.0.0.1:38991
 *   node scripts/doc-previews.ts crop <dark capture> <light capture>
 *                                         cut the pictures out of a pair of captures; the
 *                                         renderer's box lines come on stdin
 *   node scripts/doc-previews.ts write    put each picture pair under its marker
 *   node scripts/doc-previews.ts --check  change nothing; fail when a page is out of date
 *
 * Pictures live in apps/site/public/images/examples as <name>-light.webp and
 * <name>-dark.webp. The site shows the one for its theme.
 */
import { execFileSync } from 'node:child_process'
import { existsSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { createServer } from 'node:http'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const ROOT = join(import.meta.dirname, '..')
const DOCS = join(ROOT, 'docs')
const IMAGES = join(ROOT, 'apps', 'site', 'public', 'images', 'examples')
// Pages outside docs/ that show examples, by the name their pictures take.
const EXTRA: Record<string, { base: string; title: string }> = {
  'apps/site/src/content/quickstart.md': { base: 'home-quickstart', title: 'Club settings' },
}
// Only a marker on a line of its own counts; one quoted in prose does not.
const MARKER_LINE = /^<!-- preview(?: ([^\n]*?))? -->$/gm
// The picture pair the script writes on the line after a marker, then a blank
// line: Markdown would swallow a code fence right after HTML.
const FIGURE_AT = /^<figure class="example-preview[^"]*">.*<\/figure>\n\n?/
const BLOCK_AT = /^```luau[^\n]*\n([\s\S]*?)```/

function allDocs(dir = DOCS, base = ''): string[] {
  const out: string[] = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = base ? `${base}/${entry.name}` : entry.name
    if (entry.isDirectory()) {
      if (path !== 'adr') out.push(...allDocs(join(dir, entry.name), path))
    } else if (entry.name.endsWith('.md')) {
      out.push(path)
    }
  }
  return out.sort()
}

interface Page {
  file: string // path from the repo root
  base: string // picture name of its first example
  title: string
}

function pages(): Page[] {
  const out: Page[] = []
  for (const doc of allDocs()) {
    const text = readFileSync(join(DOCS, doc), 'utf8')
    const base = doc.replace(/\.md$/, '').replaceAll('/', '-')
    out.push({ file: `docs/${doc}`, base, title: text.match(/^title:\s*(.+)$/m)?.[1]?.trim() ?? base })
  }
  for (const [file, page] of Object.entries(EXTRA)) {
    if (existsSync(join(ROOT, file))) out.push({ file, ...page })
  }
  return out
}

interface Options {
  solo: boolean
  screen: boolean
  then?: string
}

function parseOptions(raw: string | undefined): Options {
  const options: Options = { solo: false, screen: false }
  for (const match of (raw ?? '').matchAll(/(\w+)(?:="([^"]*)")?/g)) {
    const [, key, value] = match
    if (key === 'solo') options.solo = true
    else if (key === 'screen') options.screen = true
    else if (key === 'then') options.then = value
    else throw new Error(`unknown preview option "${key}"`)
  }
  return options
}

interface Example extends Options {
  file: string
  name: string
  title: string
  code: string
  markerEnd: number // index just after the marker line's newline
}

function examplesOf(page: Page, text: string): Example[] {
  const out: Example[] = []
  let n = 0
  for (const found of text.matchAll(MARKER_LINE)) {
    n += 1
    const markerEnd = (found.index ?? 0) + found[0].length + 1
    const block = text.slice(markerEnd).replace(FIGURE_AT, '').match(BLOCK_AT)
    if (!block) throw new Error(`${page.file}: a preview marker is not right above a luau block`)
    let options: Options
    try {
      options = parseOptions(found[1])
    } catch (err) {
      throw new Error(`${page.file}: ${(err as Error).message}`)
    }
    out.push({
      ...options,
      file: page.file,
      name: n === 1 ? page.base : `${page.base}-${n}`,
      title: page.title,
      code: block[1] as string,
      markerEnd,
    })
  }
  return out
}

function examples(): Example[] {
  return pages().flatMap((page) => examplesOf(page, readFileSync(join(ROOT, page.file), 'utf8')))
}

function figure(example: Example): string {
  const src = (theme: string) => `/images/examples/${example.name}-${theme}.webp`
  const alt = `${example.title} example`
  return (
    `<figure class="example-preview${example.screen ? ' example-screen' : ''}">` +
    `<img class="example-light" src="${src('light')}" alt="${alt}" loading="lazy">` +
    `<img class="example-dark" src="${src('dark')}" alt="${alt}" loading="lazy">` +
    `</figure>\n\n`
  )
}

function hasPictures(name: string): boolean {
  return ['light', 'dark'].every((theme) => existsSync(join(IMAGES, `${name}-${theme}.webp`)))
}

// The page with every marked example's figure as it should be: there when both
// pictures exist, gone when they do not.
function rewrite(page: Page, text: string, missing: string[]): string {
  let out = ''
  let at = 0
  for (const example of examplesOf(page, text)) {
    out += text.slice(at, example.markerEnd)
    const old = text.slice(example.markerEnd).match(FIGURE_AT)?.[0] ?? ''
    if (hasPictures(example.name)) out += figure(example)
    else missing.push(`${page.file}: no picture yet for ${example.name}`)
    at = example.markerEnd + old.length
  }
  return out + text.slice(at)
}

const PORT = 38991
// Around what an example drew, in capture pixels.
const PAD = 40
// How far a pixel may be from the background before it counts as drawn.
const THRESHOLD = 6

interface Image {
  width: number
  height: number
  data: Buffer // RGB, row by row
}

// Reads any image cwebp takes (PNG, JPEG, WebP) through libwebp's own tools.
function decode(file: string): Image {
  const dir = mkdtempSync(join(tmpdir(), 'lucy-pictures-'))
  execFileSync('cwebp', ['-quiet', '-lossless', '-z', '0', file, '-o', join(dir, 'a.webp')])
  execFileSync('dwebp', ['-quiet', join(dir, 'a.webp'), '-ppm', '-o', join(dir, 'a.ppm')])
  const raw = readFileSync(join(dir, 'a.ppm'))
  const header = raw.toString('latin1', 0, 64).match(/^P6\s+(\d+)\s+(\d+)\s+255\s/)
  if (!header) throw new Error(`${file}: could not decode`)
  return { width: Number(header[1]), height: Number(header[2]), data: raw.subarray(header[0].length) }
}

type Rect = [number, number, number, number] // x0, y0, x1, y1

// The part of `area` that differs from the colour at its top left corner.
function drawn(image: Image, [x0, y0, x1, y1]: Rect): Rect | undefined {
  const at = (x: number, y: number) => (y * image.width + x) * 3
  const bg = at(x0, y0)
  const [r, g, b] = [image.data[bg]!, image.data[bg + 1]!, image.data[bg + 2]!]
  let box: Rect | undefined
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = at(x, y)
      const far = Math.max(Math.abs(image.data[i]! - r), Math.abs(image.data[i + 1]! - g), Math.abs(image.data[i + 2]! - b))
      if (far > THRESHOLD) {
        if (!box) box = [x, y, x + 1, y + 1]
        else box = [Math.min(box[0], x), Math.min(box[1], y), Math.max(box[2], x + 1), Math.max(box[3], y + 1)]
      }
    }
  }
  return box
}

// One picture pair per box line: the box (viewport pixels) is scaled to the capture,
// then tightened to what differs from the background in either theme, so light and
// dark get the same frame. A box that is the whole viewport (a screen) is kept whole.
function crop(darkFile: string, lightFile: string, lines: string[]): string[] {
  const dark = decode(darkFile)
  const light = decode(lightFile)
  if (dark.width !== light.width || dark.height !== light.height) throw new Error('the two captures differ in size')
  const report: string[] = []
  for (const line of lines) {
    const m = line.trim().match(/^(\S+) ([\d.]+),([\d.]+),([\d.]+),([\d.]+) vp=(\d+),(\d+)/)
    if (!m) {
      if (line.trim()) report.push(`skipped: ${line.trim()}`)
      continue
    }
    const name = m[1] as string
    const [bx0, by0, bx1, by1, vw, vh] = m.slice(2).map(Number) as [number, number, number, number, number, number]
    const scale = dark.width / vw
    let rect: Rect
    if (bx0 <= 0 && by0 <= 0 && bx1 >= vw && by1 >= vh) {
      rect = [0, 0, dark.width, Math.min(dark.height, Math.round(vh * scale))]
    } else {
      const outer: Rect = [
        Math.max(0, Math.floor(bx0 * scale) - PAD),
        Math.max(0, Math.floor(by0 * scale) - PAD),
        Math.min(dark.width, Math.ceil(bx1 * scale) + PAD),
        Math.min(dark.height, Math.ceil(by1 * scale) + PAD),
      ]
      const a = drawn(dark, outer)
      const b = drawn(light, outer)
      const ink = a && b ? ([Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[2], b[2]), Math.max(a[3], b[3])] as Rect) : (a ?? b)
      if (!ink) {
        report.push(`${name}: nothing drawn`)
        continue
      }
      rect = [
        Math.max(outer[0], ink[0] - PAD),
        Math.max(outer[1], ink[1] - PAD),
        Math.min(outer[2], ink[2] + PAD),
        Math.min(outer[3], ink[3] + PAD),
      ]
    }
    const [x0, y0, x1, y1] = rect
    for (const [theme, file] of [['dark', darkFile], ['light', lightFile]]) {
      execFileSync('cwebp', ['-quiet', '-q', '90', '-m', '6', '-crop', `${x0}`, `${y0}`, `${x1 - x0}`, `${y1 - y0}`, file as string, '-o', join(IMAGES, `${name}-${theme}.webp`)])
    }
    report.push(`${name} ${x1 - x0}x${y1 - y0}`)
  }
  return report
}

const mode = process.argv[2]
if (mode === 'serve') {
  createServer((request, response) => {
    if (request.url?.split('?')[0] !== '/examples.json') {
      response.writeHead(404).end()
      return
    }
    try {
      const body = JSON.stringify(examples().map(({ markerEnd: _, ...rest }) => rest))
      response.writeHead(200, { 'content-type': 'application/json' }).end(body)
    } catch (err) {
      response.writeHead(500).end((err as Error).message)
    }
  }).listen(PORT, '127.0.0.1', () => console.log(`serving the marked examples on http://127.0.0.1:${PORT}/examples.json`))
} else if (mode === 'crop') {
  const [darkFile, lightFile] = process.argv.slice(3)
  if (!darkFile || !lightFile) {
    console.error('usage: node scripts/doc-previews.ts crop <dark capture> <light capture> < box lines')
    process.exit(2)
  }
  for (const line of crop(darkFile, lightFile, readFileSync(0, 'utf8').split('\n'))) console.log(line)
} else if (mode === 'list') {
  console.log(JSON.stringify(examples().map(({ markerEnd: _, ...rest }) => rest), null, 2))
} else if (mode === 'blocks') {
  const out: { file: string; index: number; marked: boolean; code: string }[] = []
  for (const page of pages()) {
    const text = readFileSync(join(ROOT, page.file), 'utf8')
    let index = 0
    for (const match of text.matchAll(/^```luau[^\n]*\n([\s\S]*?)```/gm)) {
      index += 1
      const before = text.slice(0, match.index).replace(/<figure class="example-preview[^"]*">.*<\/figure>\n\n?$/, '')
      out.push({ file: page.file, index, marked: /<!-- preview(?: [^\n]*?)? -->\n$/.test(before), code: match[1] as string })
    }
  }
  console.log(JSON.stringify(out, null, 2))
} else if (mode === 'write' || mode === '--check') {
  const report: string[] = []
  for (const page of pages()) {
    const path = join(ROOT, page.file)
    const text = readFileSync(path, 'utf8')
    const missing: string[] = []
    const next = rewrite(page, text, missing)
    report.push(...missing)
    if (next !== text) {
      if (mode === 'write') writeFileSync(path, next)
      else report.push(`${page.file}: picture markup out of date`)
    }
  }
  for (const line of report) console.log(line)
  if (mode === '--check' && report.length) process.exit(1)
} else {
  console.error('usage: node scripts/doc-previews.ts list | blocks | serve | crop | write | --check')
  process.exit(2)
}
