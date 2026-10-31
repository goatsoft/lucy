/**
 * Roblox Studio, through Studio's own MCP server (ADR 0027): this spawns Studio's
 * MCP binary and calls its tools as an MCP client. Everything that depends on
 * Studio's tool names and answers is in this file, as Roblox may change them.
 */
import type { ChildProcess } from 'node:child_process'
import { spawn } from 'node:child_process'
import { existsSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { createInterface } from 'node:readline'
import type { DataModel } from './luau.ts'
import { studioError } from './luau.ts'

export interface StudioInfo {
  id: string
  /** The place, as Studio names it: "Dance Lab (placeId: 85596257011266)", "LucyTests.rbxl". */
  name: string
}

export interface Image {
  /** Base64. */
  data: string
  mimeType: string
}

export interface Studio {
  /** The Studios connected to Studio's MCP server. */
  list(): Promise<StudioInfo[]>
  /** The data models a Studio has now: `Edit`, and `Client` and `Server` while playing. */
  dataModels(id: string): Promise<string[]>
  /** Runs Luau and returns what it returned, as text. Throws the Luau error's message. */
  run(id: string, dataModel: DataModel, code: string): Promise<string>
  /** A picture of the Studio viewport. */
  capture(id: string): Promise<Image>
  close(): void
}

export interface Command {
  command: string
  args: string[]
}

const HOW_TO_TURN_ON = 'Lucy reaches Studio through Studio\'s MCP server. Install Roblox Studio and turn its MCP server on'
  + ' (Roblox\'s docs: "Studio MCP server"), or set LUCY_STUDIO_MCP to the server\'s path.'

/** Where Studio's MCP binary is: LUCY_STUDIO_MCP, or Studio's install for this platform. */
export function findStudioMcp(env: NodeJS.ProcessEnv = process.env, platform: NodeJS.Platform = process.platform): Command {
  const set = env['LUCY_STUDIO_MCP']
  if (set) return { command: set, args: [] }
  if (platform === 'darwin') return { command: '/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP', args: [] }
  if (platform === 'win32') {
    // Studio installs each version in its own folder: take the newest that has the server.
    const versions = join(env['LOCALAPPDATA'] ?? '', 'Roblox', 'Versions')
    const found = existsSync(versions)
      ? readdirSync(versions)
          .map((name) => join(versions, name, 'StudioMCP.exe'))
          .filter((file) => existsSync(file))
          .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs)
      : []
    if (found[0]) return { command: found[0], args: [] }
  }
  return { command: 'StudioMCP', args: [] }
}

interface Pending {
  resolve: (result: any) => void
  reject: (error: Error) => void
  timer: NodeJS.Timeout
}

interface ToolAnswer {
  content?: { type: string, text?: string, data?: string, mimeType?: string }[]
  isError?: boolean
}

/** Connects lazily on the first call, and again after Studio's server exits. */
export function connectStudio(command: Command = findStudioMcp(), options: { timeoutMs?: number } = {}): Studio {
  const timeoutMs = options.timeoutMs ?? 60_000
  let child: ChildProcess | undefined
  let ready: Promise<void> | undefined
  let nextId = 1
  const pending = new Map<number, Pending>()

  const failAll = (error: Error) => {
    for (const [id, p] of pending) {
      clearTimeout(p.timer)
      p.reject(error)
      pending.delete(id)
    }
    child = undefined
    ready = undefined
  }

  const send = (method: string, params: unknown): Promise<any> => new Promise((resolve, reject) => {
    if (!child?.stdin?.writable) return reject(new Error(`Studio's MCP server is not running. ${HOW_TO_TURN_ON}`))
    const id = nextId++
    const timer = setTimeout(() => {
      pending.delete(id)
      reject(new Error(`Studio did not answer within ${Math.round(timeoutMs / 1000)} s. Is it busy, or showing a dialog?`))
    }, timeoutMs)
    pending.set(id, { resolve, reject, timer })
    child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`)
  })

  const start = (): Promise<void> => {
    ready ??= new Promise<void>((resolve, reject) => {
      const proc = spawn(command.command, command.args, { stdio: ['pipe', 'pipe', 'ignore'] })
      child = proc
      proc.on('error', (error: NodeJS.ErrnoException) => {
        const why = error.code === 'ENOENT' ? `Studio's MCP server was not found at ${command.command}.` : error.message
        const failure = new Error(`${why} ${HOW_TO_TURN_ON}`)
        failAll(failure)
        reject(failure)
      })
      proc.on('exit', () => failAll(new Error(`Studio's MCP server stopped. ${HOW_TO_TURN_ON}`)))
      createInterface({ input: proc.stdout! }).on('line', (line) => {
        let message: { id?: number, result?: unknown, error?: { message?: string } }
        try {
          message = JSON.parse(line) as typeof message
        }
        catch {
          return
        }
        if (message.id === undefined) return
        const p = pending.get(message.id)
        if (!p) return
        pending.delete(message.id)
        clearTimeout(p.timer)
        if (message.error) p.reject(new Error(message.error.message ?? 'Studio\'s MCP server failed'))
        else p.resolve(message.result)
      })
      proc.on('spawn', () => {
        send('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'lucy-mcp', version: '0' } })
          .then(() => {
            proc.stdin!.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' })}\n`)
            resolve()
          }, reject)
      })
    })
    return ready
  }

  /** Calls one of Studio's tools; an error answer is thrown as its message. */
  const tool = async (name: string, args: Record<string, unknown>): Promise<ToolAnswer> => {
    await start()
    const answer = (await send('tools/call', { name, arguments: args })) as ToolAnswer
    if (answer.isError) throw new Error(studioError(textOf(answer) || `Studio's ${name} failed`))
    return answer
  }

  return {
    async list() {
      const answer = await tool('list_roblox_studios', {})
      const parsed = JSON.parse(textOf(answer) || '{}') as { studios?: StudioInfo[] }
      return (parsed.studios ?? []).map(({ id, name }) => ({ id, name }))
    },
    async dataModels(id) {
      const answer = await tool('get_studio_state', { studio_id: id })
      const line = /Available DataModels:\s*(.*)/.exec(textOf(answer))
      return line?.[1] ? line[1].split(',').map((s) => s.trim()).filter(Boolean) : ['Edit']
    },
    async run(id, dataModel, code) {
      return textOf(await tool('execute_luau', { studio_id: id, datamodel_type: dataModel, code }))
    },
    async capture(id) {
      const answer = await tool('screen_capture', { studio_id: id, capture_id: `LucyMcp_${Date.now()}` })
      const image = answer.content?.find((c) => c.type === 'image')
      if (!image?.data) throw new Error('Studio sent no picture')
      return { data: image.data, mimeType: image.mimeType ?? 'image/jpeg' }
    },
    close() {
      const running = child
      failAll(new Error('closed'))
      running?.kill()
    },
  }
}

function textOf(answer: ToolAnswer): string {
  return (answer.content ?? []).filter((c) => c.type === 'text').map((c) => c.text ?? '').join('\n')
}
