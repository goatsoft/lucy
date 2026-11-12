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
 *   <!-- preview screen trim -->     a whole client script, its picture cut to what
 *                                    it drew (a centred panel), as other examples are
 *   <!-- preview world -->           a whole client script that draws in the world (an aura,
 *                                    a part): shown full screen with no backdrop, the
 *                                    camera put back and what it made in workspace removed
 *   <!-- preview then="..." -->      Luau run after the example (any kind), to go to
 *                                    a scene or open a menu first
 *   <!-- preview animate -->         capture multiple frames with Animate.step and
 *   <!-- preview animate="2.0" -->   write a looping animated WebP pair (optional
 *                                    fps="12" and warmup="0.5")
 *
 * Names: the first marked example on docs/components/button.md is
 * components-button, the second components-button-2, and so on. The homepage's
 * example (apps/site/src/content/quickstart.md) is home-quickstart.
 *
 *   node scripts/doc-previews.ts list     print the marked examples as JSON
 *   node scripts/doc-previews.ts blocks   print every luau block, marked or not
 *   node scripts/doc-previews.ts render [name ...]
 *                                         draw the marked examples (or just these) in the
 *                                         LucyTests Studio, capture them and write the
 *                                         pictures; no HTTP: Studio's MCP server runs the
 *                                         renderer (scripts/doc-pictures.luau) and captures
 *   node scripts/doc-previews.ts crop <dark capture> <light capture>
 *                                         the same from two captures made another way, with
 *                                         the renderer's box lines on stdin
 *   node scripts/doc-previews.ts write    put each picture pair under its marker
 *   node scripts/doc-previews.ts --check  change nothing; fail when a page is out of date
 *
 * Pictures live in apps/site/public/images/examples as <name>-light.webp and
 * <name>-dark.webp. The site shows the one for its theme.
 */
import { execFileSync } from 'node:child_process'
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { connectStudio } from '../libs/mcp/src/studio.ts'
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
  trim: boolean
  world: boolean
  then?: string
  animate?: number
  fps?: number
  warmup?: number
}

function parseOptions(raw: string | undefined): Options {
  const options: Options = { solo: false, screen: false, trim: false, world: false }
  for (const match of (raw ?? '').matchAll(/(\w+)(?:="([^"]*)")?/g)) {
    const [, key, value] = match
    if (key === 'solo') options.solo = true
    else if (key === 'screen') options.screen = true
    else if (key === 'trim') options.trim = true
    else if (key === 'world') {
      options.world = true
      options.screen = true
    }
    else if (key === 'then') options.then = value
    else if (key === 'animate') {
      const duration = value === undefined ? 1.6 : Number(value)
      if (!Number.isFinite(duration) || duration <= 0) throw new Error(`invalid animate duration "${value}"`)
      options.animate = duration
    } else if (key === 'fps') {
      const fps = Number(value)
      if (!Number.isFinite(fps) || fps <= 0) throw new Error(`invalid fps "${value}"`)
      options.fps = fps
    } else if (key === 'warmup') {
      const warmup = Number(value)
      if (!Number.isFinite(warmup) || warmup < 0) throw new Error(`invalid warmup "${value}"`)
      options.warmup = warmup
    } else throw new Error(`unknown preview option "${key}"`)
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
    `<figure class="example-preview${example.trim ? ' example-trim' : example.screen ? ' example-screen' : ''}">` +
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

// The frame both pictures of a pair share: what either theme drew inside `area`,
// plus PAD, kept inside `area`.
function frame(dark: Image, light: Image, area: Rect): Rect | undefined {
  const a = drawn(dark, area)
  const b = drawn(light, area)
  const ink = a && b ? ([Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[2], b[2]), Math.max(a[3], b[3])] as Rect) : (a ?? b)
  if (!ink) return undefined
  return [
    Math.max(area[0], ink[0] - PAD),
    Math.max(area[1], ink[1] - PAD),
    Math.min(area[2], ink[2] + PAD),
    Math.min(area[3], ink[3] + PAD),
  ]
}

function writePpm(image: Image, [x0, y0, x1, y1]: Rect, file: string) {
  const width = x1 - x0
  const height = y1 - y0
  const rows = Buffer.alloc(width * height * 3)
  for (let y = 0; y < height; y++) {
    const from = ((y0 + y) * image.width + x0) * 3
    image.data.copy(rows, y * width * 3, from, from + width * 3)
  }
  writeFileSync(file, Buffer.concat([Buffer.from(`P6\n${width} ${height}\n255\n`, 'latin1'), rows]))
}

// Writes `rect` of `image` as apps/site/public/images/examples/<file>.
function writeWebp(image: Image, rect: Rect, file: string) {
  const dir = mkdtempSync(join(tmpdir(), 'lucy-pictures-'))
  try {
    const ppm = join(dir, 'a.ppm')
    writePpm(image, rect, ppm)
    execFileSync('cwebp', ['-quiet', '-q', '90', '-m', '6', ppm, '-o', join(IMAGES, file)])
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

function writeAnimatedWebp(images: Image[], rect: Rect, delayMs: number, file: string) {
  const dir = mkdtempSync(join(tmpdir(), 'lucy-anim-'))
  try {
    const args = ['-min_size', '-mixed', '-loop', '0', '-d', String(delayMs), '-lossy', '-q', '85', '-m', '6']
    images.forEach((image, index) => {
      const ppm = join(dir, `f${String(index).padStart(3, '0')}.ppm`)
      writePpm(image, rect, ppm)
      args.push(ppm)
    })
    args.push('-o', join(IMAGES, file))
    execFileSync('img2webp', args, { stdio: 'pipe' })
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

// A picture pair from a dark and a light image of the same place: cut to what was
// drawn inside `area`, or the whole of it for a screen.
function writePair(name: string, dark: Image, light: Image, area: Rect, whole: boolean): string {
  const rect = whole ? area : frame(dark, light, area)
  if (!rect) return `${name}: nothing drawn`
  writeWebp(dark, rect, `${name}-dark.webp`)
  writeWebp(light, rect, `${name}-light.webp`)
  return `${name} ${rect[2] - rect[0]}x${rect[3] - rect[1]}`
}

function framesRect(images: Image[], area: Rect): Rect | undefined {
  let ink: Rect | undefined
  for (const img of images) {
    const box = drawn(img, area)
    if (!box) continue
    ink = ink
      ? [Math.min(ink[0], box[0]), Math.min(ink[1], box[1]), Math.max(ink[2], box[2]), Math.max(ink[3], box[3])]
      : box
  }
  if (!ink) return undefined
  return [
    Math.max(area[0], ink[0] - PAD),
    Math.max(area[1], ink[1] - PAD),
    Math.min(area[2], ink[2] + PAD),
    Math.min(area[3], ink[3] + PAD),
  ]
}

function writeAnimatedPair(name: string, darkFiles: string[], lightFiles: string[], area: Rect, whole: boolean, delayMs: number): string {
  const dark = darkFiles.map(decode)
  const light = lightFiles.map(decode)
  for (const img of [...dark.slice(1), ...light]) {
    if (img.width !== dark[0]!.width || img.height !== dark[0]!.height) throw new Error(`${name}: captured frames differ in size`)
  }
  const rect = whole ? area : framesRect([...dark, ...light], area)
  if (!rect) return `${name}: nothing drawn`
  writeAnimatedWebp(dark, rect, delayMs, `${name}-dark.webp`)
  writeAnimatedWebp(light, rect, delayMs, `${name}-light.webp`)
  return `${name} ${rect[2] - rect[0]}x${rect[3] - rect[1]} (${dark.length} frames @ ${delayMs}ms)`
}

function parseBoxLine(line: string, width: number, height: number): { name: string; area: Rect; whole: boolean } | undefined {
  const m = line.trim().match(/^(\S+) ([\d.]+),([\d.]+),([\d.]+),([\d.]+) vp=(\d+),(\d+)/)
  if (!m) return undefined
  const name = m[1] as string
  const [bx0, by0, bx1, by1, vw, vh] = m.slice(2).map(Number) as [number, number, number, number, number, number]
  const scale = width / vw
  const isScreen = bx0 <= 0 && by0 <= 0 && bx1 >= vw && by1 >= vh
  const trimmed = examples().some((example) => example.name === name && example.trim)
  const whole = isScreen && !trimmed
  const area: Rect = isScreen
    ? [0, 0, width, Math.min(height, Math.round(vh * scale))]
    : [
        Math.max(0, Math.floor(bx0 * scale) - PAD),
        Math.max(0, Math.floor(by0 * scale) - PAD),
        Math.min(width, Math.ceil(bx1 * scale) + PAD),
        Math.min(height, Math.ceil(by1 * scale) + PAD),
      ]
  return { name, area, whole }
}

// One picture pair per box line: the box (viewport pixels) is scaled to the capture
// and padded. A box that is the whole viewport (a screen) is kept whole.
function crop(darkFile: string, lightFile: string, lines: string[]): string[] {
  const dark = decode(darkFile)
  const light = decode(lightFile)
  if (dark.width !== light.width || dark.height !== light.height) throw new Error('the two captures differ in size')
  const report: string[] = []
  for (const line of lines) {
    const parsed = parseBoxLine(line, dark.width, dark.height)
    if (!parsed) {
      if (line.trim()) report.push(`skipped: ${line.trim()}`)
      continue
    }
    report.push(writePair(parsed.name, dark, light, parsed.area, parsed.whole))
  }
  return report
}

// Draws the examples in the LucyTests Studio and writes their pictures, through Studio's MCP
// server (the Lucy MCP's Studio client): no HTTP from Studio. Each screenful is drawn dark, then
// light at the same places, each captured, and the pairs cropped from the two captures.
async function render(names: string[]) {
  const all = examples().map(({ markerEnd: _, ...rest }) => rest)
  const picked = names.length ? all.filter((example) => names.includes(example.name)) : all
  const unknown = names.filter((name) => !all.some((example) => example.name === name))
  if (unknown.length) throw new Error(`no marked example named ${unknown.join(', ')}`)
  const json = JSON.stringify(picked)
  if (json.includes(']==]')) throw new Error('an example holds the text ]==], which ends the Luau string')

  const studio = connectStudio()
  try {
    const target = (await studio.list()).find((s) => s.name.includes('LucyTests'))
    if (!target) throw new Error('open the LucyTests place in Studio, in edit mode, with Studio as MCP server on')
    const luau = (code: string) => studio.run(target.id, 'Edit', code)
    const settle = () => new Promise((resolve) => setTimeout(resolve, 1000))
    // A world example's camera is set by its script, which a plain capture of the edit view does
    // not follow: capture from where the script put it.
    const shot = async () => {
      const view = (await luau('return _G.LucyDocPicturesRun.view()')).trim().split(',').map(Number)
      const at = view.length === 6 && view.every(Number.isFinite) ? { from: view.slice(0, 3), at: view.slice(3) } : undefined
      return studio.capture(target.id, at)
    }
    const dir = mkdtempSync(join(tmpdir(), 'lucy-captures-'))
    const saveCapture = (filePrefix: string, shot: { data: string; mimeType: string }) => {
      const file = join(dir, `${filePrefix}.${shot.mimeType.endsWith('png') ? 'png' : 'jpg'}`)
      writeFileSync(file, Buffer.from(shot.data, 'base64'))
      return file
    }
    console.log(await luau(`
local list = game:GetService("HttpService"):JSONDecode([==[${json}]==])
local R = require(game.ReplicatedStorage.LucyDocPictures:Clone())
_G.LucyDocPicturesRun = R
return R.start(list)
`))
    try {
      for (let screen = 1; ; screen++) {
        const lines = await luau('return _G.LucyDocPicturesRun.next("dark")')
        if (lines.trim() === 'done') break
        if (lines.startsWith('ANIMATE ')) {
          const name = lines.slice('ANIMATE '.length).trim()
          const ex = picked.find((e) => e.name === name)
          if (!ex) throw new Error(`unexpected animated example "${name}"`)
          const fps = ex.fps ?? 12
          const count = Math.max(2, Math.round((ex.animate ?? 1.6) * fps))
          const dt = 1 / fps
          const delayMs = Math.round(1000 / fps)
          const captureRun = async (theme: 'dark' | 'light') => {
            const files: string[] = []
            for (let i = 0; i < count; i++) {
              if (i > 0) await luau(`return _G.LucyDocPicturesRun.step(${dt})`)
              else await new Promise((resolve) => setTimeout(resolve, 120))
              files.push(saveCapture(`${screen}-${theme}-${i}`, await shot()))
            }
            return files
          }
          const darkFiles = await captureRun('dark')
          const lightStart = await luau('return _G.LucyDocPicturesRun.again("light")')
          if (/ ERR /.test(lightStart)) {
            console.error(lightStart)
            continue
          }
          const lightFiles = await captureRun('light')
          const boxLine = await luau('return _G.LucyDocPicturesRun.box()')
          if (/ (?:ERR|EMPTY)\b/.test(boxLine)) {
            console.error(boxLine)
            continue
          }
          const first = decode(darkFiles[0]!)
          const parsed = parseBoxLine(boxLine, first.width, first.height)
          if (!parsed) {
            console.error(`bad box line: ${boxLine}`)
            continue
          }
          console.log(writeAnimatedPair(name, darkFiles, lightFiles, parsed.area, parsed.whole, delayMs))
          continue
        }
        await settle()
        const darkFile = saveCapture(`${screen}-dark`, await shot())
        await luau('return _G.LucyDocPicturesRun.again("light")')
        await settle()
        const lightFile = saveCapture(`${screen}-light`, await shot())
        const drawnLines = lines.split('\n').filter((line) => !line.endsWith(' LATER') && !/ ERR /.test(line))
        for (const line of lines.split('\n').filter((line) => / ERR /.test(line))) console.error(line)
        for (const line of crop(darkFile, lightFile, drawnLines)) console.log(line)
      }
    } finally {
      rmSync(dir, { recursive: true, force: true })
      console.log(await luau('local R = _G.LucyDocPicturesRun if R then R.stop() end _G.LucyDocPicturesRun = nil return "stopped"'))
    }
  } finally {
    studio.close()
  }
}

const mode = process.argv[2]
if (mode === 'render') {
  await render(process.argv.slice(3))
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
