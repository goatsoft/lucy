import { readdir, readFile } from 'node:fs/promises'
import { extname, join, relative, resolve } from 'node:path'

// A quoted string that looks like "set:name". Whether `set` is an icon set is
// decided later, against the known prefixes.
const QUOTED = /(["'`])([a-z0-9]+(?:-[a-z0-9]+)*:[a-z0-9]+(?:[-_][a-z0-9]+)*)\1/g

/** Every quoted "set:name" string in some source text. */
export function namesIn(text: string): string[] {
  const out: string[] = []
  for (const match of text.matchAll(QUOTED)) {
    out.push(match[2] as string)
  }
  return out
}

export interface Found {
  /** name -> the files it appears in, relative to the root */
  names: Map<string, string[]>
  files: number
}

/** Scans `dirs` under `root` for files with `extensions`, skipping `skip` (absolute paths). */
export async function scan(root: string, dirs: string[], extensions: string[], skip: string[]): Promise<Found> {
  const names = new Map<string, string[]>()
  const skipped = new Set(skip.map(p => resolve(p)))
  let files = 0
  const walk = async (dir: string): Promise<void> => {
    let entries
    try {
      entries = await readdir(dir, { withFileTypes: true })
    } catch {
      return
    }
    for (const entry of entries) {
      const path = join(dir, entry.name)
      if (entry.isDirectory()) {
        if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue
        await walk(path)
      } else if (extensions.includes(extname(entry.name)) && !skipped.has(resolve(path))) {
        files += 1
        const where = relative(root, path)
        for (const name of namesIn(await readFile(path, 'utf8'))) {
          const list = names.get(name)
          if (list === undefined) names.set(name, [where])
          else if (!list.includes(where)) list.push(where)
        }
      }
    }
  }
  for (const dir of dirs) await walk(resolve(root, dir))
  return { names, files }
}
