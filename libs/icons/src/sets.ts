import { createRequire } from 'node:module'
import { mkdir, readdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import type { IconifyInfo, IconifyJSON } from '@iconify/types'

export const API = 'https://api.iconify.design'

/** What the build needs to know about a set. */
export interface SetInfo {
  prefix: string
  name: string
  licence: string
  licenceUrl: string
  /** Attribution required by the licence (CC BY and the like). */
  attribution: boolean
  /** Icons keep their own colours; never tinted. */
  palette: boolean
}

export interface Sources {
  /** Every prefix this source knows. */
  prefixes(): Promise<Set<string>>
  info(prefix: string): Promise<SetInfo | undefined>
  /** Icon data for `names` of a set (more is fine). Missing names are left out. */
  icons(prefix: string, names: string[]): Promise<IconifyJSON | undefined>
}

type Fetch = (url: string) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>

const NEEDS_ATTRIBUTION = /^(CC-BY|CC BY|OFL)/i

function toInfo(prefix: string, info: Partial<IconifyInfo> | undefined): SetInfo {
  const spdx = info?.license?.spdx ?? info?.license?.title ?? 'unknown'
  return {
    prefix,
    name: info?.name ?? prefix,
    licence: spdx,
    licenceUrl: info?.license?.url ?? '',
    attribution: NEEDS_ATTRIBUTION.test(spdx) && !/^CC0/i.test(spdx),
    palette: info?.palette === true,
  }
}

/**
 * Sets installed as @iconify-json/<prefix> packages, found from each folder in
 * `from` (the game first, then this tool).
 */
export function installed(from: string[]): Sources {
  const requires = from.map(dir => createRequire(join(dir, 'package.json')))
  const resolveFile = (prefix: string, file: string): string | undefined => {
    for (const require of requires) {
      try {
        return require.resolve(`@iconify-json/${prefix}/${file}`)
      } catch {
        // not installed here
      }
    }
    return undefined
  }
  const cache = new Map<string, IconifyJSON>()
  return {
    async prefixes() {
      const out = new Set<string>()
      for (const dir of from) {
        try {
          for (const name of await readdir(join(dir, 'node_modules', '@iconify-json'))) out.add(name)
        } catch {
          // none here
        }
      }
      return out
    },
    async info(prefix) {
      const file = resolveFile(prefix, 'info.json')
      if (file === undefined) return undefined
      return toInfo(prefix, JSON.parse(await readFile(file, 'utf8')) as IconifyInfo)
    },
    async icons(prefix) {
      const hit = cache.get(prefix)
      if (hit) return hit
      const file = resolveFile(prefix, 'icons.json')
      if (file === undefined) return undefined
      const set = JSON.parse(await readFile(file, 'utf8')) as IconifyJSON
      cache.set(prefix, set)
      return set
    },
  }
}

/**
 * The Iconify API, with what it returns kept under `cacheDir`, so each icon is
 * downloaded once. `offline` uses only the cache.
 */
export function api(cacheDir: string, options: { fetch?: Fetch; offline?: boolean } = {}): Sources {
  const fetcher: Fetch = options.fetch ?? ((url: string) => fetch(url))
  const offline = options.offline === true
  let collections: Record<string, Partial<IconifyInfo>> | undefined

  const readJson = async <T>(path: string): Promise<T | undefined> => {
    try {
      return JSON.parse(await readFile(path, 'utf8')) as T
    } catch {
      return undefined
    }
  }
  const writeJson = async (path: string, value: unknown) => {
    await mkdir(dirname(path), { recursive: true })
    await writeFile(path, JSON.stringify(value))
  }
  const get = async (url: string): Promise<unknown> => {
    const response = await fetcher(url)
    if (!response.ok) throw new Error(`${url} answered ${response.status}`)
    return response.json()
  }

  const loadCollections = async () => {
    if (collections) return collections
    const file = join(cacheDir, 'collections.json')
    collections = await readJson<Record<string, Partial<IconifyInfo>>>(file)
    if (!collections) {
      if (offline) return (collections = {})
      collections = (await get(`${API}/collections`)) as Record<string, Partial<IconifyInfo>>
      await writeJson(file, collections)
    }
    return collections
  }

  return {
    async prefixes() {
      return new Set(Object.keys(await loadCollections()))
    },
    async info(prefix) {
      const all = await loadCollections()
      return prefix in all ? toInfo(prefix, all[prefix]) : undefined
    },
    async icons(prefix, names) {
      const file = join(cacheDir, 'sets', `${prefix}.json`)
      const cached = (await readJson<IconifyJSON>(file)) ?? { prefix, icons: {} }
      const have = (n: string) => n in cached.icons || (cached.aliases !== undefined && n in cached.aliases)
      const missing = names.filter(n => !have(n) && !(cached.not_found ?? []).includes(n))
      if (missing.length > 0 && !offline) {
        const got = (await get(`${API}/${prefix}.json?icons=${missing.map(encodeURIComponent).join(',')}`)) as
          | IconifyJSON
          | number
        if (typeof got === 'object') {
          Object.assign(cached.icons, got.icons)
          if (got.aliases) cached.aliases = { ...cached.aliases, ...got.aliases }
          if (got.not_found) cached.not_found = [...new Set([...(cached.not_found ?? []), ...got.not_found])]
          for (const key of ['width', 'height', 'left', 'top'] as const) {
            if (got[key] !== undefined) cached[key] = got[key]
          }
          await writeJson(file, cached)
        }
      }
      return cached
    },
  }
}

/** Installed sets first; the API for anything not installed. */
export function chain(...sources: Sources[]): Sources {
  return {
    async prefixes() {
      const out = new Set<string>()
      for (const source of sources) for (const p of await source.prefixes()) out.add(p)
      return out
    },
    async info(prefix) {
      for (const source of sources) {
        const info = await source.info(prefix)
        if (info) return info
      }
      return undefined
    },
    async icons(prefix, names) {
      for (const source of sources) {
        const set = await source.icons(prefix, names)
        if (set) return set
      }
      return undefined
    },
  }
}

/** This tool's own folder, where its devDependency sets live (used by tests). */
export const toolDir = dirname(dirname(fileURLToPath(import.meta.url)))
