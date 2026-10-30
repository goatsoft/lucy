import { readFile, writeFile } from 'node:fs/promises'
import { sameLayout, type Layout } from './layout.ts'

/**
 * lucy-icons.lock.json. `order` is every icon's slot: new icons take slots at
 * the end and removed ones keep theirs, so sheets that hold no new icon stay
 * byte for byte the same and are never uploaded again. `sheets` maps each
 * sheet's content hash to its asset id.
 */
export interface Lock extends Layout {
  version: 1
  order: string[]
  sheets: Record<string, string>
}

export function emptyLock(layout: Layout): Lock {
  return { version: 1, ...layout, order: [], sheets: {} }
}

export async function readLock(path: string, layout: Layout): Promise<Lock> {
  let text: string
  try {
    text = await readFile(path, 'utf8')
  } catch {
    return emptyLock(layout)
  }
  const raw = JSON.parse(text) as Partial<Lock>
  if (raw.version !== 1 || !Array.isArray(raw.order) || typeof raw.sheets !== 'object' || raw.sheets === null) {
    throw new Error(`${path} is not a lucy-icons lock file`)
  }
  return {
    version: 1,
    size: Number(raw.size),
    sheet: Number(raw.sheet),
    padding: Number(raw.padding),
    order: raw.order.map(String),
    sheets: Object.fromEntries(Object.entries(raw.sheets).map(([k, v]) => [k, String(v)])),
  }
}

export async function writeLock(path: string, lock: Lock): Promise<void> {
  const sorted = Object.fromEntries(Object.entries(lock.sheets).sort(([a], [b]) => a.localeCompare(b)))
  await writeFile(path, JSON.stringify({ ...lock, sheets: sorted }, null, 2) + '\n')
}

export interface Ordered {
  order: string[]
  added: string[]
  repacked: boolean
}

/**
 * The slot order for `used`: the lock's order with new names appended in
 * sorted order. Starts over, sorted, when asked to repack or when the layout
 * changed (old slots would not line up).
 */
export function orderFor(lock: Lock, used: Iterable<string>, layout: Layout, repack: boolean): Ordered {
  const wanted = [...new Set(used)].sort()
  if (repack || !sameLayout(lock, layout)) {
    return { order: wanted, added: wanted.filter(n => !lock.order.includes(n)), repacked: true }
  }
  const known = new Set(lock.order)
  const added = wanted.filter(n => !known.has(n))
  return { order: [...lock.order, ...added], added, repacked: false }
}
