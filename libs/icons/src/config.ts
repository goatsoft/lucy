import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'

/** lucy-icons.json, in the game's folder. Paths are relative to that folder. */
export interface Config {
  /** Folders to scan for icon names. */
  src: string[]
  /** File extensions to scan. */
  extensions: string[]
  /** Names built at runtime, which a scan cannot find. */
  include: string[]
  /** The generated Luau module. */
  output: string
  /** The lock file, committed with the game. */
  lock: string
  /** Cell size in pixels. */
  size: number
  /** Sheet width and height in pixels. */
  sheet: number
  /** Space around each cell in pixels, so neighbours never bleed in. */
  padding: number
  /** Who owns the uploads: a user id or a group id. */
  creator?: { userId?: string; groupId?: string }
  /** Where downloaded icon data and unuploaded sheets go. */
  cache: string
}

export const defaults: Config = {
  src: ['src'],
  extensions: ['.luau', '.lua'],
  include: [],
  output: 'src/shared/Icons.luau',
  lock: 'lucy-icons.lock.json',
  size: 64,
  sheet: 1024,
  padding: 4,
  cache: '.lucy-icons',
}

export interface Loaded {
  config: Config
  /** The folder holding the config. */
  root: string
}

export async function loadConfig(path: string): Promise<Loaded> {
  const file = resolve(path)
  let raw: unknown
  try {
    raw = JSON.parse(await readFile(file, 'utf8'))
  } catch (error) {
    throw new Error(`could not read ${file}: ${(error as Error).message}`)
  }
  return { config: parseConfig(raw), root: dirname(file) }
}

export function parseConfig(raw: unknown): Config {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new Error('the config must be a JSON object')
  }
  const input = raw as Record<string, unknown>
  const config: Config = { ...defaults }
  const strings = (key: 'src' | 'extensions' | 'include') => {
    const value = input[key]
    if (value === undefined) return
    if (!Array.isArray(value) || value.some(v => typeof v !== 'string')) {
      throw new Error(`"${key}" must be a list of strings`)
    }
    config[key] = value as string[]
  }
  const text = (key: 'output' | 'lock' | 'cache') => {
    const value = input[key]
    if (value === undefined) return
    if (typeof value !== 'string' || value === '') throw new Error(`"${key}" must be a path`)
    config[key] = value
  }
  const number = (key: 'size' | 'sheet' | 'padding', min: number) => {
    const value = input[key]
    if (value === undefined) return
    if (typeof value !== 'number' || !Number.isInteger(value) || value < min) {
      throw new Error(`"${key}" must be a whole number of at least ${min}`)
    }
    config[key] = value
  }
  strings('src')
  strings('extensions')
  strings('include')
  text('output')
  text('lock')
  text('cache')
  number('size', 8)
  number('sheet', 64)
  number('padding', 0)
  if (config.sheet > 4096) throw new Error('"sheet" can be at most 4096')
  if (config.size + config.padding * 2 > config.sheet) throw new Error('a cell does not fit in a sheet')
  const creator = input['creator']
  if (creator !== undefined) {
    if (typeof creator !== 'object' || creator === null) throw new Error('"creator" must be { "userId" } or { "groupId" }')
    const c = creator as Record<string, unknown>
    const userId = c['userId'], groupId = c['groupId']
    if ((userId === undefined) === (groupId === undefined)) {
      throw new Error('"creator" needs exactly one of "userId" or "groupId"')
    }
    const id = String(userId ?? groupId)
    if (!/^\d+$/.test(id)) throw new Error('the creator id must be a number')
    config.creator = userId !== undefined ? { userId: id } : { groupId: id }
  }
  for (const name of config.include) {
    if (!isName(name)) throw new Error(`"${name}" in "include" is not a set:name icon name`)
  }
  return config
}

const NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*:[a-z0-9]+(?:[-_][a-z0-9]+)*$/

export function isName(value: string): boolean {
  return NAME.test(value)
}
