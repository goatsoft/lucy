import assert from 'node:assert/strict'
import { test } from 'node:test'
import { devtoolsCall, longString, parseReply, studioError } from './luau.ts'

/** What a Luau long string holds: the text between its brackets, a leading newline dropped. */
function unquote(literal: string): string {
  const open = /^\[(=*)\[/.exec(literal)
  assert.ok(open, `not a long string: ${literal}`)
  const eq = open[1] ?? ''
  const close = `]${eq}]`
  let body = literal.slice(open[0].length)
  const end = body.indexOf(close)
  assert.equal(end, body.length - close.length, `closes early: ${literal}`)
  body = body.slice(0, end)
  return body.startsWith('\n') ? body.slice(1) : body
}

test('longString holds any text unchanged', () => {
  for (const text of ['', 'plain', 'a]]b', 'ends with ]', 'ends with ]=', ']=]]==]', '\nstarts with a newline', '{"a":"\\"q\\""}', 'é ✓ 🎵']) {
    assert.equal(unquote(longString(text)), text, JSON.stringify(text))
  }
})

test('devtoolsCall carries the request as JSON in a long string', () => {
  const code = devtoolsCall({ method: 'press', id: 'buy]]', value: 3, app: 'Lucy_' }, 'Client')
  const literal = /JSONDecode\((\[=*\[[\s\S]*?\]=*\])\)/.exec(code)
  assert.ok(literal?.[1], 'the request is decoded from a long string')
  assert.deepEqual(JSON.parse(unquote(literal[1])), { method: 'press', id: 'buy]]', value: 3, app: 'Lucy_' })
})

test('devtoolsCall takes a fresh copy of Lucy for a preview, and reuses it for edit-mode reads', () => {
  // Edit-mode require is cached, so a preview needs a new copy; a shown story's
  // app keeps requiring from the copy it came from, so later calls reuse it.
  assert.match(devtoolsCall({ method: 'preview', story: 'Button' }, 'Edit'), /local fresh = true\nlocal edit = true/)
  assert.match(devtoolsCall({ method: 'tree' }, 'Edit'), /local fresh = false\nlocal edit = true/)
  assert.match(devtoolsCall({ method: 'tree' }, 'Client'), /local fresh = false\nlocal edit = false/)
})

test('devtoolsCall clears the preview and drops the kept copy when no story is given', () => {
  const code = devtoolsCall({ method: 'preview' }, 'Edit')
  assert.match(code, /local fresh = true/)
  assert.match(code, /if m == "preview" and request.story == nil then/)
})

test('in edit mode, devtoolsCall never requires the cached Lucy: it makes a copy when none is kept', () => {
  assert.match(devtoolsCall({ method: 'apps' }, 'Edit'), /elseif edit then\n\t\tmodule = kept or copyOf\(module\)/)
})

test('devtoolsCall tells a Lucy too old for Devtools from no Lucy at all', () => {
  const code = devtoolsCall({ method: 'apps' }, 'Client')
  assert.match(code, /has no Devtools: update Lucy/)
  assert.match(code, /Lucy is not in ReplicatedStorage/)
})

test('devtoolsCall waits before answering when a screenshot follows', () => {
  assert.match(devtoolsCall({ method: 'press', id: 'x' }, 'Client', { settle: 0.4 }), /task\.wait\(0\.4\)/)
  assert.doesNotMatch(devtoolsCall({ method: 'press', id: 'x' }, 'Client'), /task\.wait\(0\.4\)/)
})

test('parseReply returns the result, or throws the Luau error', () => {
  assert.deepEqual(parseReply('{"ok":true,"result":{"coins":1250}}'), { coins: 1250 })
  assert.equal(parseReply('{"ok":true}'), null)
  assert.throws(() => parseReply('{"ok":false,"error":"[Lucy] Devtools: no component \\"x\\""}'), /no component "x"/)
  assert.throws(() => parseReply('not json'), /Studio answered with something else: not json/)
})

test('studioError keeps only the message from Studio\'s error text', () => {
  const raw = 'sabuiltin_Assistant.rbxm.Assistant.Tools.ExecuteLuauTool:125: sabuiltin_Assistant.rbxm.Util.CommandExecution:54: AssistantCommand:1: boom'
  assert.equal(studioError(raw), 'boom')
  assert.equal(studioError('Studio is not responding'), 'Studio is not responding')
})
