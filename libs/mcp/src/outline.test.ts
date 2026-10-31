import assert from 'node:assert/strict'
import { test } from 'node:test'
import { outline } from './outline.ts'

test('outline writes one line per component, children indented', () => {
  const tree = [
    {
      id: 'shop',
      kind: 'panel',
      shown: true,
      flags: [],
      text: '',
      size: [400, 300],
      position: [10, 20],
      state: [],
      children: [
        { id: 'buy', kind: 'button', shown: true, flags: ['focused', 'focus-visible'], text: 'Buy', size: [120, 40], position: [20, 240], state: [], children: [] },
        { id: 'music', kind: 'slider', shown: false, flags: ['disabled'], text: '', size: [200, 20], position: [0, 0], state: { value: 80, max: 100 }, children: [] },
      ],
    },
  ]
  assert.equal(outline(tree), [
    'panel #shop 400x300 at 10,20',
    '  button #buy "Buy" [focused, focus-visible] 120x40 at 20,240',
    '  slider #music [disabled] (hidden) 200x20 at 0,0 state: value=80 max=100',
  ].join('\n'))
})

test('outline quotes text on one line and keeps state values short', () => {
  const tree = [{ id: 'note', kind: 'text', shown: true, flags: [], text: 'Two\nlines "quoted"', state: { items: ['a', 'b'], label: 'Hi' }, children: [] }]
  assert.equal(outline(tree), 'text #note "Two\\nlines \\"quoted\\"" state: items=["a","b"] label="Hi"')
})

test('outline says when there is nothing on screen', () => {
  assert.equal(outline([]), '(no components)')
})
