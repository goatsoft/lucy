import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'
import { connectStudio, findStudioMcp } from './studio.ts'

/** A stand-in for Studio's MCP binary: answers the calls studio.ts makes, as Studio does. */
const FAKE = `
import { createInterface } from 'node:readline'
const send = (m) => process.stdout.write(JSON.stringify(m) + '\\n')
const text = (t, isError = false) => ({ content: [{ type: 'text', text: t }], isError })
createInterface({ input: process.stdin }).on('line', (line) => {
  const m = JSON.parse(line)
  if (m.id === undefined) return
  if (m.method === 'initialize') return send({ jsonrpc: '2.0', id: m.id, result: { protocolVersion: '2025-06-18', capabilities: { tools: {} }, serverInfo: { name: 'RobloxStudio', version: '1' } } })
  const { name, arguments: a } = m.params
  let result
  if (name === 'list_roblox_studios') result = text(JSON.stringify({ studios: [{ id: 's1', name: 'LucyTests.rbxl' }] }))
  else if (name === 'get_studio_state') result = text('- Current Studio Mode: Play\\n- Available DataModels: Edit, Client, Server\\n- Focused DataModel in the viewport: Client')
  else if (name === 'execute_luau') result = a.code === 'boom'
    ? text('sabuiltin_Assistant.rbxm.X:1: AssistantCommand:1: boom', true)
    : text(a.datamodel_type + ':' + a.studio_id + ':' + a.code)
  else if (name === 'screen_capture') result = { content: [{ type: 'image', data: 'aGk=', mimeType: 'image/jpeg' }], isError: false }
  send({ jsonrpc: '2.0', id: m.id, result })
})
`

function fakeBinary(): string {
  const dir = mkdtempSync(join(tmpdir(), 'lucy-mcp-'))
  const file = join(dir, 'fake-studio.mjs')
  writeFileSync(file, FAKE)
  return file
}

test('talks to Studio\'s MCP server: list, data models, run, capture', async () => {
  const studio = connectStudio({ command: process.execPath, args: [fakeBinary()] })
  try {
    assert.deepEqual(await studio.list(), [{ id: 's1', name: 'LucyTests.rbxl' }])
    assert.deepEqual(await studio.dataModels('s1'), ['Edit', 'Client', 'Server'])
    assert.equal(await studio.run('s1', 'Client', 'return 1'), 'Client:s1:return 1')
    await assert.rejects(studio.run('s1', 'Edit', 'boom'), /^Error: boom$/)
    assert.deepEqual(await studio.capture('s1'), { data: 'aGk=', mimeType: 'image/jpeg' })
  }
  finally {
    studio.close()
  }
})

test('a missing binary says how to get Studio\'s MCP server', async () => {
  const studio = connectStudio({ command: join(tmpdir(), 'no-such-studio-mcp'), args: [] })
  try {
    await assert.rejects(studio.list(), /Studio's MCP server/)
  }
  finally {
    studio.close()
  }
})

test('findStudioMcp prefers LUCY_STUDIO_MCP, then the platform\'s install', () => {
  assert.deepEqual(findStudioMcp({ LUCY_STUDIO_MCP: '/x/StudioMCP' }, 'darwin'), { command: '/x/StudioMCP', args: [] })
  assert.deepEqual(findStudioMcp({}, 'darwin'), { command: '/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP', args: [] })
})
