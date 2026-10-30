import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, join, relative, resolve } from 'node:path'
import { loadConfig } from './config.ts'
import type { Layout } from './layout.ts'
import { slot } from './layout.ts'
import { orderFor, readLock, writeLock, type Lock } from './lock.ts'
import { luauModule, type Entry } from './output.ts'
import { draw, hash, renderPng, sheetSvg, type Drawn } from './render.ts'
import { scan } from './scan.ts'
import { api, chain, installed, toolDir, type SetInfo, type Sources } from './sets.ts'
import { openCloud, type Uploader } from './upload.ts'

export const API_KEY_ENV = 'LUCY_ICONS_API_KEY'

export interface BuildOptions {
  /** Path to lucy-icons.json. */
  config: string
  /** Where icon data comes from. Defaults to installed sets, then the Iconify API. */
  sources?: Sources
  /** How sheets are uploaded. Defaults to Open Cloud when LUCY_ICONS_API_KEY is set. */
  upload?: Uploader
  /** Never upload: write new sheets for a manual upload instead. */
  noUpload?: boolean
  /** Change nothing; report whether the module and lock are up to date. */
  check?: boolean
  /** Start the slot order over, sorted. Every sheet changes. */
  repack?: boolean
  /** Use only installed sets and the cache. */
  offline?: boolean
  env?: Record<string, string | undefined>
  log?: (line: string) => void
}

export type Status = 'written' | 'unchanged' | 'outdated' | 'needs-upload'

export interface BuildResult {
  status: Status
  /** Icons in the module, sorted. */
  icons: string[]
  sheets: number
  uploaded: number
  /** PNGs waiting for a manual upload. */
  pending: { file: string; hash: string }[]
  output: string
}

function group(names: Iterable<string>): Map<string, string[]> {
  const out = new Map<string, string[]>()
  for (const name of names) {
    const prefix = name.slice(0, name.indexOf(':'))
    const list = out.get(prefix)
    if (list) list.push(name)
    else out.set(prefix, [name])
  }
  return out
}

async function readText(path: string): Promise<string | undefined> {
  try {
    return await readFile(path, 'utf8')
  } catch {
    return undefined
  }
}

export async function build(options: BuildOptions): Promise<BuildResult> {
  const log = options.log ?? (() => {})
  const env = options.env ?? process.env
  const { config, root } = await loadConfig(options.config)
  const layout: Layout = { size: config.size, sheet: config.sheet, padding: config.padding }
  const output = resolve(root, config.output)
  const lockPath = resolve(root, config.lock)
  const cacheDir = resolve(root, config.cache)
  const sources =
    options.sources ??
    chain(installed([root, toolDir]), api(join(cacheDir, 'data'), { offline: options.offline === true }))

  // 1. The names the game uses.
  const found = await scan(root, config.src, config.extensions, [output])
  const known = await sources.prefixes()
  const used = new Map<string, string[]>()
  for (const [name, files] of found.names) {
    if (known.has(name.slice(0, name.indexOf(':')))) used.set(name, files)
  }
  const problems: string[] = []
  for (const name of config.include) {
    const prefix = name.slice(0, name.indexOf(':'))
    if (!known.has(prefix)) problems.push(`"${name}" in include: there is no icon set "${prefix}"`)
    else if (!used.has(name)) used.set(name, ['lucy-icons.json'])
  }
  log(`found ${used.size} icon${used.size === 1 ? '' : 's'} in ${found.files} files`)

  // 2. Slots: the lock's order, new icons at the end.
  const lock = await readLock(lockPath, layout)
  const ordered = orderFor(lock, used.keys(), layout, options.repack === true)
  if (ordered.repacked && lock.order.length > 0) log('starting the sheets over: every sheet changes')

  // 3. Draw every slot, including removed icons that keep theirs (so their sheet stays the same).
  const infos = new Map<string, SetInfo>()
  const drawn = new Map<string, Drawn>()
  for (const [prefix, names] of group(ordered.order)) {
    const info = (await sources.info(prefix)) ?? {
      prefix,
      name: prefix,
      licence: 'unknown',
      licenceUrl: '',
      attribution: false,
      palette: false,
    }
    infos.set(prefix, info)
    const set = await sources.icons(prefix, names.map(n => n.slice(prefix.length + 1)))
    for (const name of names) {
      const index = ordered.order.indexOf(name)
      const icon = set ? draw(set, name, index, info.palette) : undefined
      if (icon) drawn.set(name, icon)
      else if (used.has(name)) problems.push(`unknown icon "${name}" (in ${(used.get(name) ?? []).join(', ')})`)
    }
  }
  if (problems.length > 0) throw new Error(problems.join('\n'))

  // 4. Sheets.
  const bySheet = new Map<number, { drawn: Drawn; index: number }[]>()
  ordered.order.forEach((name, index) => {
    const icon = drawn.get(name)
    if (!icon) return
    const sheet = slot(index, layout).sheet
    const list = bySheet.get(sheet)
    if (list) list.push({ drawn: icon, index })
    else bySheet.set(sheet, [{ drawn: icon, index }])
  })
  const sheetCount = bySheet.size === 0 ? 0 : Math.max(...bySheet.keys()) + 1
  const pngs: { png: Buffer; hash: string }[] = []
  for (let i = 0; i < sheetCount; i++) {
    const png = renderPng(sheetSvg(bySheet.get(i) ?? [], layout))
    pngs.push({ png, hash: hash(png) })
  }

  // 5. Asset ids: the lock's, or new uploads.
  const ids: string[] = pngs.map(p => lock.sheets[p.hash] ?? '')
  const missing = pngs.map((p, i) => ({ ...p, i })).filter(p => ids[p.i] === '')
  const entries: Entry[] = [...used.keys()].map(name => ({
    name,
    index: ordered.order.indexOf(name),
    tint: (drawn.get(name) as Drawn).tint,
  }))
  const newLock: Lock = {
    version: 1,
    ...layout,
    order: ordered.order,
    sheets: Object.fromEntries(pngs.map((p, i) => [p.hash, ids[i] as string]).filter(([, id]) => id !== '')),
  }
  const base: Omit<BuildResult, 'status'> = {
    icons: entries.map(e => e.name).sort(),
    sheets: sheetCount,
    uploaded: 0,
    pending: [],
    output: relative(root, output),
  }

  if (options.check) {
    if (missing.length > 0) return { ...base, status: 'outdated' }
    const text = luauModule(entries, ids, layout, [...group(used.keys()).keys()].map(p => infos.get(p) as SetInfo))
    const same = (await readText(output)) === text && JSON.stringify(lock.order) === JSON.stringify(ordered.order)
    return { ...base, status: same ? 'unchanged' : 'outdated' }
  }

  let uploader = options.upload
  if (!uploader && missing.length > 0 && !options.noUpload) {
    const key = env[API_KEY_ENV]
    if (key) {
      if (!config.creator) throw new Error(`set "creator" in the config ({ "userId": ... } or { "groupId": ... }) to upload`)
      uploader = openCloud(key, config.creator)
    }
  }

  if (missing.length > 0 && (options.noUpload || !uploader)) {
    const pending: { file: string; hash: string }[] = []
    for (const p of missing) {
      const file = join(cacheDir, 'sheets', `${p.hash}.png`)
      await mkdir(dirname(file), { recursive: true })
      await writeFile(file, p.png)
      pending.push({ file: relative(root, file), hash: p.hash })
    }
    await writeLock(lockPath, newLock)
    return { ...base, status: 'needs-upload', pending }
  }

  let uploaded = 0
  for (const p of missing) {
    log(`uploading sheet ${p.i + 1} of ${sheetCount}`)
    const id = await (uploader as Uploader)(p.png, `lucy-icons-${p.hash.slice(0, 8)}`)
    ids[p.i] = id
    newLock.sheets[p.hash] = id
    uploaded += 1
    // Saved after each upload, so a failure later never loses an upload.
    await writeLock(lockPath, newLock)
  }

  const text = luauModule(entries, ids, layout, [...group(used.keys()).keys()].map(p => infos.get(p) as SetInfo))
  const before = await readText(output)
  await writeLock(lockPath, newLock)
  if (before === text) return { ...base, uploaded, status: 'unchanged' }
  await mkdir(dirname(output), { recursive: true })
  await writeFile(output, text)
  return { ...base, uploaded, status: 'written' }
}
