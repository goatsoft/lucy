import assert from 'node:assert/strict'
import { PassThrough } from 'node:stream'
import { test } from 'node:test'
import { serve } from './server.ts'
import type { Tool } from './tools.ts'

const echo: Tool = {
  name: 'echo',
  description: 'Says back what it was given.',
  inputSchema: { type: 'object', properties: { says: { type: 'string' } } },
  run: async (args) => ({ content: [{ type: 'text', text: String(args['says']) }] }),
}

/** Sends `messages` (one per line) and returns every reply, after the input ends. */
async function exchange(messages: (object | string)[]): Promise<any[]> {
  const input = new PassThrough()
  const output = new PassThrough()
  let written = ''
  output.on('data', (chunk) => (written += chunk))
  const done = serve(input, output, [echo], { name: 'lucy', version: '9.9.9' })
  for (const m of messages) input.write(`${typeof m === 'string' ? m : JSON.stringify(m)}\n`)
  input.end()
  await done
  return written.split('\n').filter(Boolean).map((line) => JSON.parse(line))
}

test('initialize answers with the server, its tools capability and the agreed protocol', async () => {
  const [reply] = await exchange([{ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 't', version: '0' } } }])
  assert.equal(reply.id, 1)
  assert.equal(reply.result.protocolVersion, '2025-06-18')
  assert.deepEqual(reply.result.serverInfo, { name: 'lucy', version: '9.9.9' })
  assert.ok(reply.result.capabilities.tools)
  assert.equal(typeof reply.result.instructions, 'string')
})

test('initialize with a protocol it does not know offers its latest', async () => {
  const [reply] = await exchange([{ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '1999-01-01' } }])
  assert.equal(reply.result.protocolVersion, '2025-06-18')
})

test('tools/list gives names, descriptions and schemas', async () => {
  const [reply] = await exchange([{ jsonrpc: '2.0', id: 2, method: 'tools/list' }])
  assert.deepEqual(reply.result.tools, [{ name: 'echo', description: echo.description, inputSchema: echo.inputSchema }])
})

test('tools/call runs the tool', async () => {
  const [reply] = await exchange([{ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'echo', arguments: { says: 'hi' } } }])
  assert.deepEqual(reply.result, { content: [{ type: 'text', text: 'hi' }] })
})

test('tools/call for a tool it does not have is an invalid-params error', async () => {
  const [reply] = await exchange([{ jsonrpc: '2.0', id: 4, method: 'tools/call', params: { name: 'nope' } }])
  assert.equal(reply.error.code, -32602)
  assert.match(reply.error.message, /nope/)
})

test('a tool that throws reports the error as a tool result', async () => {
  const thrower: Tool = { ...echo, name: 'boom', run: async () => { throw new Error('kaboom') } }
  const input = new PassThrough()
  const output = new PassThrough()
  let written = ''
  output.on('data', (c) => (written += c))
  const done = serve(input, output, [thrower], { name: 'lucy', version: '0' })
  input.end(`${JSON.stringify({ jsonrpc: '2.0', id: 5, method: 'tools/call', params: { name: 'boom', arguments: {} } })}\n`)
  await done
  assert.deepEqual(JSON.parse(written).result, { content: [{ type: 'text', text: 'kaboom' }], isError: true })
})

test('ping, notifications, unknown methods and bad JSON', async () => {
  const replies = await exchange([
    { jsonrpc: '2.0', id: 6, method: 'ping' },
    { jsonrpc: '2.0', method: 'notifications/initialized' },
    { jsonrpc: '2.0', id: 7, method: 'resources/list' },
    '{not json',
  ])
  // Replies need not come in order: each is matched by its id.
  const byId = new Map(replies.map((r) => [r.id, r]))
  assert.deepEqual(byId.get(6), { jsonrpc: '2.0', id: 6, result: {} })
  assert.equal(byId.get(7).error.code, -32601)
  assert.equal(byId.get(null).error.code, -32700)
  assert.equal(replies.length, 3)
})

test('replies may come back out of order, each with its id', async () => {
  const slow: Tool = { ...echo, name: 'slow', run: async () => { await new Promise((r) => setTimeout(r, 30)); return { content: [{ type: 'text', text: 'slow' }] } } }
  const input = new PassThrough()
  const output = new PassThrough()
  let written = ''
  output.on('data', (c) => (written += c))
  const done = serve(input, output, [slow, echo], { name: 'lucy', version: '0' })
  input.write(`${JSON.stringify({ jsonrpc: '2.0', id: 'a', method: 'tools/call', params: { name: 'slow' } })}\n`)
  input.write(`${JSON.stringify({ jsonrpc: '2.0', id: 'b', method: 'tools/call', params: { name: 'echo', arguments: { says: 'fast' } } })}\n`)
  input.end()
  await done
  const ids = written.split('\n').filter(Boolean).map((l) => JSON.parse(l).id)
  assert.deepEqual(ids, ['b', 'a'])
})
