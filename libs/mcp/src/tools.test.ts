import assert from 'node:assert/strict'
import { test } from 'node:test'
import type { DataModel } from './luau.ts'
import { readRequest } from './luau.ts'
import type { Studio, StudioInfo } from './studio.ts'
import type { ToolResult } from './tools.ts'
import { createTools } from './tools.ts'

interface Call { id: string, dataModel: DataModel, request: Record<string, unknown> }

/** A Studio that answers every Devtools request with `answer(request)`. */
function fakeStudio(options: {
  studios?: StudioInfo[]
  playing?: boolean
  answer?: (request: Record<string, unknown>) => unknown
  fail?: string
} = {}) {
  const calls: Call[] = []
  let captures = 0
  const studio: Studio = {
    list: async () => options.studios ?? [{ id: 's1', name: 'LucyTests.rbxl' }],
    dataModels: async () => (options.playing ? ['Edit', 'Client', 'Server'] : ['Edit']),
    run: async (id, dataModel, code) => {
      const request = readRequest(code)
      calls.push({ id, dataModel, request })
      if (options.fail) throw new Error(options.fail)
      const result = options.answer ? options.answer(request) : null
      return JSON.stringify(result instanceof Error ? { ok: false, error: result.message } : { ok: true, result })
    },
    capture: async () => {
      captures++
      return { data: 'aGk=', mimeType: 'image/jpeg' }
    },
    close: () => {},
  }
  return { studio, calls, captures: () => captures }
}

async function call(studio: Studio, name: string, args: Record<string, unknown> = {}): Promise<ToolResult> {
  const tool = createTools(studio).find((t) => t.name === name)
  assert.ok(tool, `no tool ${name}`)
  return tool.run(args)
}

const text = (result: ToolResult) => result.content.map((c) => (c.type === 'text' ? c.text : `<${c.type}>`)).join('\n')

test('every tool has a description and an object schema', () => {
  const { studio } = fakeStudio()
  const names = createTools(studio).map((t) => t.name)
  assert.deepEqual(names.sort(), ['actions', 'apps', 'focus', 'overlays', 'press', 'preview', 'screenshot', 'set', 'state', 'studios', 'tree'])
  for (const tool of createTools(studio)) {
    assert.ok(tool.description.length > 20, tool.name)
    assert.equal(tool.inputSchema.type, 'object', tool.name)
  }
})

test('studios lists the open Studios', async () => {
  const { studio } = fakeStudio({ studios: [{ id: 'a', name: 'Dance Lab (placeId: 1)' }, { id: 'b', name: 'LucyTests.rbxl' }] })
  assert.equal(text(await call(studio, 'studios')), 'a  Dance Lab (placeId: 1)\nb  LucyTests.rbxl')
})

test('with one Studio open, tools use it without being told', async () => {
  const { studio, calls } = fakeStudio({ answer: () => [] })
  await call(studio, 'tree')
  assert.equal(calls[0]?.id, 's1')
})

test('with several open, a tool needs `studio`, by id or by part of its name', async () => {
  const studios = [{ id: 'a', name: 'Dance Lab (placeId: 1)' }, { id: 'b', name: 'LucyTests.rbxl' }]
  const { studio, calls } = fakeStudio({ studios, answer: () => [] })
  const missing = await call(studio, 'tree')
  assert.equal(missing.isError, true)
  assert.match(text(missing), /Several Studios are open.*"Dance Lab \(placeId: 1\)" \(a\).*"LucyTests.rbxl" \(b\)/s)
  await call(studio, 'tree', { studio: 'dance lab' })
  await call(studio, 'tree', { studio: 'b' })
  assert.deepEqual(calls.map((c) => c.id), ['a', 'b'])
  const unknown = await call(studio, 'tree', { studio: 'Bagman' })
  assert.match(text(unknown), /No open Studio matches "Bagman"/)
})

test('no Studio open: the tool says how to get one', async () => {
  const { studio } = fakeStudio({ studios: [] })
  const result = await call(studio, 'tree')
  assert.equal(result.isError, true)
  assert.match(text(result), /No Studio is connected/)
})

test('game tools run on the client in Play, in edit mode otherwise', async () => {
  const playing = fakeStudio({ playing: true, answer: () => [] })
  await call(playing.studio, 'tree')
  assert.equal(playing.calls[0]?.dataModel, 'Client')
  const editing = fakeStudio({ answer: () => [] })
  await call(editing.studio, 'tree')
  assert.equal(editing.calls[0]?.dataModel, 'Edit')
})

test('tree is an outline by default and JSON on request', async () => {
  const node = { id: 'buy', kind: 'button', shown: true, flags: [], text: 'Buy', state: [], children: [] }
  const { studio, calls } = fakeStudio({ answer: () => [node] })
  assert.equal(text(await call(studio, 'tree', { root: 'shop', shownOnly: true, app: 'Lucy_' })), 'button #buy "Buy"')
  assert.deepEqual(calls[0]?.request, { method: 'tree', root: 'shop', shownOnly: true, app: 'Lucy_' })
  assert.deepEqual(JSON.parse(text(await call(studio, 'tree', { format: 'json' }))), [node])
})

test('press, set and focus pass their arguments through', async () => {
  const { studio, calls } = fakeStudio({ answer: () => ({ ok: true }) })
  await call(studio, 'press', { id: 'music', value: 40 })
  await call(studio, 'set', { path: 'player.coins', value: { n: 10 } })
  await call(studio, 'focus', { id: 'buy' })
  await call(studio, 'focus')
  await call(studio, 'state', { path: 'player' })
  assert.deepEqual(calls.map((c) => c.request), [
    { method: 'press', id: 'music', value: 40 },
    { method: 'set', path: 'player.coins', value: { n: 10 } },
    { method: 'focus', id: 'buy' },
    { method: 'focus' },
    { method: 'state', path: 'player' },
  ])
})

test('a press Lucy refuses is an error, with its reason', async () => {
  const { studio } = fakeStudio({ answer: () => ({ ok: false, reason: '"buy" is disabled' }) })
  const result = await call(studio, 'press', { id: 'buy' })
  assert.equal(result.isError, true)
  assert.equal(text(result), '"buy" is disabled')
})

test('a Devtools error comes back as the tool\'s error', async () => {
  const { studio } = fakeStudio({ answer: () => new Error('[Lucy] Devtools: no component "nope"') })
  const result = await call(studio, 'press', { id: 'nope' })
  assert.equal(result.isError, true)
  assert.equal(text(result), '[Lucy] Devtools: no component "nope"')
})

test('Studio failing comes back as the tool\'s error', async () => {
  const { studio } = fakeStudio({ fail: 'Studio did not answer' })
  const result = await call(studio, 'apps')
  assert.equal(result.isError, true)
  assert.equal(text(result), 'Studio did not answer')
})

test('screenshot: true adds a picture after acting', async () => {
  const fake = fakeStudio({ answer: () => ({ ok: true }) })
  const result = await call(fake.studio, 'press', { id: 'emote-shop', screenshot: true })
  assert.equal(fake.captures(), 1)
  assert.deepEqual(result.content.at(-1), { type: 'image', data: 'aGk=', mimeType: 'image/jpeg' })
  await call(fake.studio, 'press', { id: 'emote-shop' })
  assert.equal(fake.captures(), 1)
})

test('preview shows a story in edit mode, even during Play, and takes a picture', async () => {
  const fake = fakeStudio({ playing: true, answer: () => ({ ok: true, story: 'Button' }) })
  const result = await call(fake.studio, 'preview', { story: 'Button', theme: 'light' })
  assert.deepEqual(fake.calls[0]?.request, { method: 'preview', story: 'Button', theme: 'light' })
  assert.equal(fake.calls[0]?.dataModel, 'Edit')
  assert.equal(fake.captures(), 1)
  assert.equal(result.content[0]?.type, 'text')
})

test('preview without a story takes the shown one away, with no picture', async () => {
  const fake = fakeStudio({ answer: () => ({ ok: true, cleared: true }) })
  const result = await call(fake.studio, 'preview', {})
  assert.deepEqual(fake.calls[0]?.request, { method: 'preview' })
  assert.equal(fake.calls[0]?.dataModel, 'Edit')
  assert.equal(fake.captures(), 0)
  assert.equal(result.isError, undefined)
})

test('screenshot takes a picture of the Studio window', async () => {
  const fake = fakeStudio()
  const result = await call(fake.studio, 'screenshot')
  assert.deepEqual(result.content, [{ type: 'image', data: 'aGk=', mimeType: 'image/jpeg' }])
})
