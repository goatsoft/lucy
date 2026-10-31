/**
 * The MCP side: JSON-RPC over stdio, one message per line. It answers the
 * handshake, lists the tools and runs them; replies go out as each call ends.
 */
import { createInterface } from 'node:readline'
import type { Readable, Writable } from 'node:stream'
import type { Tool } from './tools.ts'

/** Protocol versions this server speaks, newest first. */
const PROTOCOLS = ['2025-06-18', '2025-03-26', '2024-11-05']

const INSTRUCTIONS = `Lucy's tools look at and drive a running Lucy UI in Roblox Studio, through Studio's own MCP server.
Start with \`tree\` to see the components and their ids, then \`press\`, \`focus\` and \`set\` to act as a player would,
and \`state\` to check what changed. Add \`screenshot: true\` to see the result.
The game's UI is reachable while it runs in Play (start it with Studio's start_stop_play); tools then run on the client by themselves.
In edit mode, \`preview\` shows a single story to look at and press.`

export interface ServerInfo {
  name: string
  version: string
}

interface Message {
  jsonrpc?: string
  id?: string | number | null
  method?: string
  params?: Record<string, any>
}

/** Serves `tools` on `input` / `output` until the input ends and every call has answered. */
export function serve(input: Readable, output: Writable, tools: Tool[], info: ServerInfo): Promise<void> {
  const byName = new Map(tools.map((tool) => [tool.name, tool]))
  const write = (message: object) => output.write(`${JSON.stringify(message)}\n`)
  const inflight = new Set<Promise<void>>()

  const handle = async (message: Message): Promise<object> => {
    const id = message.id ?? null
    const ok = (result: object) => ({ jsonrpc: '2.0', id, result })
    const fail = (code: number, text: string) => ({ jsonrpc: '2.0', id, error: { code, message: text } })
    switch (message.method) {
      case 'initialize': {
        const asked = message.params?.['protocolVersion']
        return ok({
          protocolVersion: PROTOCOLS.includes(asked) ? asked : PROTOCOLS[0],
          capabilities: { tools: {} },
          serverInfo: info,
          instructions: INSTRUCTIONS,
        })
      }
      case 'ping':
        return ok({})
      case 'tools/list':
        return ok({ tools: tools.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })) })
      case 'tools/call': {
        const name = String(message.params?.['name'])
        const tool = byName.get(name)
        if (!tool) return fail(-32602, `No tool named "${name}"`)
        try {
          return ok(await tool.run((message.params?.['arguments'] ?? {}) as Record<string, unknown>))
        }
        catch (error) {
          return ok({ content: [{ type: 'text', text: (error as Error).message }], isError: true })
        }
      }
      default:
        return fail(-32601, `Method not found: ${message.method}`)
    }
  }

  return new Promise((resolve) => {
    const lines = createInterface({ input })
    lines.on('line', (line) => {
      if (!line.trim()) return
      let message: Message
      try {
        message = JSON.parse(line) as Message
      }
      catch {
        write({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } })
        return
      }
      // Notifications (no id) and replies to us (no method) need no answer.
      if (message.id === undefined || message.id === null || !message.method) return
      const done = handle(message).then(write, (error: Error) => {
        write({ jsonrpc: '2.0', id: message.id, error: { code: -32603, message: error.message } })
      }).then(() => {
        inflight.delete(done)
      })
      inflight.add(done)
    })
    lines.on('close', () => {
      void Promise.all(inflight).then(() => resolve())
    })
  })
}
