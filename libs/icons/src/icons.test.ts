import assert from 'node:assert/strict'
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, it } from 'node:test'
import { build } from './build.ts'
import { parseConfig } from './config.ts'
import { columns, perSheet, slot } from './layout.ts'
import { emptyLock, orderFor } from './lock.ts'
import { luauModule } from './output.ts'
import { draw, hash, prefixIds, renderPng, sheetSvg } from './render.ts'
import { namesIn } from './scan.ts'
import { LUCY_SLOTS } from './slots.ts'
import { chain, installed, toolDir, type Sources } from './sets.ts'

const layout = { size: 64, sheet: 1024, padding: 4 }

describe('scan', () => {
  it('finds quoted set:name strings', () => {
    const text = `Icon.new({ icon = "lucide:heart" }) local x = 'mdi:account-circle' print(\`tabler:x\`)`
    assert.deepEqual(namesIn(text), ['lucide:heart', 'mdi:account-circle', 'tabler:x'])
  })
  it('ignores urls, ids and partial matches', () => {
    const text = `"rbxassetid://12" "ui.play" "Lucide:Heart" "lucide:heart extra" "a:b:c"`
    assert.deepEqual(namesIn(text), [])
  })
})

describe('config', () => {
  it('fills defaults and checks values', () => {
    const config = parseConfig({ include: ['lucide:star'], creator: { groupId: 42 } })
    assert.equal(config.size, 64)
    assert.deepEqual(config.creator, { groupId: '42' })
    assert.throws(() => parseConfig({ include: ['star'] }), /not a set:name/)
    assert.throws(() => parseConfig({ creator: { userId: 1, groupId: 2 } }), /exactly one/)
    assert.throws(() => parseConfig({ size: 2000, sheet: 1024 }), /does not fit/)
    assert.equal(config.lucy, true)
    assert.equal(parseConfig({ lucy: false }).lucy, false)
    assert.throws(() => parseConfig({ lucy: 'no' }), /"lucy" must be true or false/)
  })
})

describe('layout', () => {
  it('fills sheets row by row', () => {
    assert.equal(columns(layout), 14) // 1024 / 72
    assert.equal(perSheet(layout), 196)
    assert.deepEqual(slot(0, layout), { sheet: 0, x: 4, y: 4 })
    assert.deepEqual(slot(15, layout), { sheet: 0, x: 76, y: 76 })
    assert.deepEqual(slot(196, layout), { sheet: 1, x: 4, y: 4 })
  })
})

describe('lock order', () => {
  it('keeps old slots and appends new names sorted', () => {
    const lock = { ...emptyLock(layout), order: ['lucide:star', 'lucide:heart'] }
    const ordered = orderFor(lock, ['lucide:zap', 'lucide:heart', 'lucide:bell'], layout, false)
    assert.deepEqual(ordered.order, ['lucide:star', 'lucide:heart', 'lucide:bell', 'lucide:zap'])
    assert.deepEqual(ordered.added, ['lucide:bell', 'lucide:zap'])
    assert.equal(ordered.repacked, false)
  })
  it('starts over when repacking or when the layout changed', () => {
    const lock = { ...emptyLock(layout), order: ['lucide:star', 'lucide:heart'] }
    assert.deepEqual(orderFor(lock, ['lucide:heart'], layout, true).order, ['lucide:heart'])
    assert.equal(orderFor(lock, ['lucide:heart'], { ...layout, size: 48 }, false).repacked, true)
  })
})

describe('render', () => {
  it('paints one colour icons white and keeps palette icons', async () => {
    const set = await installed([toolDir]).icons('lucide', ['heart'])
    assert.ok(set)
    const heart = draw(set, 'lucide:heart', 3, false)
    assert.ok(heart)
    assert.ok(heart.body.includes('#ffffff'))
    assert.ok(!heart.body.includes('currentColor'))
    assert.equal(heart.tint, true)
    assert.equal(draw(set, 'lucide:heart', 3, true)?.tint, false)
    assert.equal(draw(set, 'lucide:not-an-icon', 0, false), undefined)
    const png = renderPng(sheetSvg([{ drawn: heart, index: 0 }], layout))
    assert.deepEqual([...png.subarray(1, 4)], [...Buffer.from('PNG')])
  })
})

describe('ids', () => {
  it('prefixes ids and their references, the same way every time', () => {
    const body = '<defs><linearGradient id="a"/></defs><path fill="url(#a)"/><use href="#a"/><g id="ab"/>'
    const out = prefixIds(body, 'i7_')
    assert.equal(out, '<defs><linearGradient id="i7_a"/></defs><path fill="url(#i7_a)"/><use href="#i7_a"/><g id="i7_ab"/>')
    assert.equal(prefixIds(body, 'i7_'), out)
    assert.equal(prefixIds('<path d="M0"/>', 'i1_'), '<path d="M0"/>')
  })
  it('renders the same sheet to the same bytes', async () => {
    const set = await installed([toolDir]).icons('lucide', ['heart', 'star'])
    assert.ok(set)
    const icons = ['lucide:heart', 'lucide:star'].map((name, index) => ({ drawn: draw(set, name, index, false)!, index }))
    assert.equal(hash(renderPng(sheetSvg(icons, layout))), hash(renderPng(sheetSvg(icons, layout))))
  })
})

describe('output', () => {
  it('writes the map Lucy.Icon.register takes', () => {
    const text = luauModule(
      [
        { name: 'lucide:star', index: 1, tint: true },
        { name: 'game:logo', index: 196, tint: false },
      ],
      ['111', '222'],
      layout,
      [{ prefix: 'lucide', name: 'Lucide', licence: 'ISC', licenceUrl: '', attribution: false, palette: false }],
    )
    assert.match(text, /local sheet1 = "rbxassetid:\/\/111"/)
    assert.match(text, /local sheet2 = "rbxassetid:\/\/222"/)
    assert.match(text, /\["lucide:star"\] = \{ image = sheet1, rect = \{ 76, 4, 64, 64 \} \},/)
    assert.match(text, /\["game:logo"\] = \{ image = sheet2, rect = \{ 4, 4, 64, 64 \}, tint = false \},/)
    assert.match(text, /lucide: Lucide, ISC/)
    assert.ok(text.indexOf('game:logo') < text.indexOf('lucide:star'), 'sorted by name')
  })
})

// End to end, with installed Lucide data and no network. Games leave Lucy's
// slots out unless a test asks (`lucy: undefined` gives the default).
async function game(files: Record<string, string>, config: Record<string, unknown> = {}) {
  const root = await mkdtemp(join(tmpdir(), 'lucy-icons-'))
  await writeFile(join(root, 'lucy-icons.json'), JSON.stringify({ output: 'src/Icons.luau', lucy: false, ...config }))
  for (const [path, text] of Object.entries(files)) {
    await mkdir(join(root, path, '..'), { recursive: true })
    await writeFile(join(root, path), text)
  }
  return root
}

const offlineSources: Sources = chain(installed([toolDir]))

function fakeUploads() {
  const uploads: string[] = []
  return {
    uploads,
    upload: async (_png: Buffer, name: string) => {
      uploads.push(name)
      return String(1000 + uploads.length)
    },
  }
}

describe('build', () => {
  it('packs used icons, uploads each new sheet once and writes the module', async () => {
    const root = await game({
      'src/Hud.luau': `Icon.new({ icon = "lucide:heart" }) Icon.new({ icon = "lucide:star" }) local s = "ui:not-a-set"`,
    })
    try {
      const fake = fakeUploads()
      const options = { config: join(root, 'lucy-icons.json'), sources: offlineSources, upload: fake.upload }

      const first = await build(options)
      assert.equal(first.status, 'written')
      assert.deepEqual(first.icons, ['lucide:heart', 'lucide:star'])
      assert.equal(fake.uploads.length, 1)
      const module = await readFile(join(root, 'src/Icons.luau'), 'utf8')
      assert.match(module, /\["lucide:heart"\] = \{ image = sheet1, rect = \{ 4, 4, 64, 64 \} \},/)
      assert.match(module, /rbxassetid:\/\/1001/)

      // Nothing changed: no upload, nothing written.
      const again = await build(options)
      assert.equal(again.status, 'unchanged')
      assert.equal(fake.uploads.length, 1)
      assert.equal((await build({ ...options, check: true })).status, 'unchanged')

      // A new icon takes the next slot; the old ones keep theirs.
      await writeFile(join(root, 'src/Menu.luau'), `Icon.new({ icon = "lucide:bell" })`)
      assert.equal((await build({ ...options, check: true })).status, 'outdated')
      const added = await build(options)
      assert.equal(added.status, 'written')
      assert.equal(fake.uploads.length, 2)
      const lock = JSON.parse(await readFile(join(root, 'lucy-icons.lock.json'), 'utf8'))
      assert.deepEqual(lock.order, ['lucide:heart', 'lucide:star', 'lucide:bell'])
      assert.match(await readFile(join(root, 'src/Icons.luau'), 'utf8'), /\["lucide:heart"\] = \{ image = sheet1, rect = \{ 4, 4,/)

      // Removing an icon keeps its slot, so the sheet is the same and nothing uploads.
      await writeFile(join(root, 'src/Menu.luau'), `-- no icons`)
      const removed = await build(options)
      assert.equal(removed.status, 'written')
      assert.equal(fake.uploads.length, 2)
      assert.deepEqual(removed.icons, ['lucide:heart', 'lucide:star'])
      assert.ok(!(await readFile(join(root, 'src/Icons.luau'), 'utf8')).includes('lucide:bell'))
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('adds names from include and fails on an unknown icon', async () => {
    const root = await game({ 'src/A.luau': `local i = "lucide:no-such-icon-here"` }, { include: ['lucide:zap'] })
    try {
      await assert.rejects(
        build({ config: join(root, 'lucy-icons.json'), sources: offlineSources, upload: fakeUploads().upload }),
        /unknown icon "lucide:no-such-icon-here" \(in src\/A.luau\)/,
      )
      await writeFile(join(root, 'src/A.luau'), '')
      const result = await build({ config: join(root, 'lucy-icons.json'), sources: offlineSources, upload: fakeUploads().upload })
      assert.deepEqual(result.icons, ['lucide:zap'])
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('leaves sheets for a manual upload without a key', async () => {
    const root = await game({ 'src/A.luau': `local i = "lucide:heart"` })
    try {
      const options = { config: join(root, 'lucy-icons.json'), sources: offlineSources, env: {} }
      const result = await build(options)
      assert.equal(result.status, 'needs-upload')
      assert.equal(result.pending.length, 1)
      const pending = result.pending[0] as { file: string; hash: string }
      assert.ok((await readFile(join(root, pending.file))).length > 0)

      // The ids go in the lock by hand; then the build writes the module.
      const lockPath = join(root, 'lucy-icons.lock.json')
      const lock = JSON.parse(await readFile(lockPath, 'utf8'))
      lock.sheets[pending.hash] = '777'
      await writeFile(lockPath, JSON.stringify(lock))
      const done = await build(options)
      assert.equal(done.status, 'written')
      assert.match(await readFile(join(root, 'src/Icons.luau'), 'utf8'), /rbxassetid:\/\/777/)
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('never scans its own output', async () => {
    const root = await game({ 'src/A.luau': `local i = "lucide:heart"` })
    try {
      const fake = fakeUploads()
      const options = { config: join(root, 'lucy-icons.json'), sources: offlineSources, upload: fake.upload }
      await build(options)
      await writeFile(join(root, 'src/A.luau'), '')
      const result = await build(options)
      assert.deepEqual(result.icons, [])
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })
})

describe("Lucy's slots", () => {
  const cell = (module: string, name: string) =>
    module.match(new RegExp(`\\["${name}"\\] = \\{ (image = sheet\\d+, rect = \\{[^}]*\\}[^}]*)\\},`))?.[1]

  it('writes every slot into the module by default, drawn from the icon that fills it', async () => {
    const root = await game({ 'src/A.luau': `local i = "lucide:heart"` }, { lucy: undefined })
    try {
      const result = await build({ config: join(root, 'lucy-icons.json'), sources: offlineSources, upload: fakeUploads().upload })
      assert.deepEqual(result.icons, ['lucide:heart', ...Object.keys(LUCY_SLOTS)].sort())
      const module = await readFile(join(root, 'src/Icons.luau'), 'utf8')
      for (const slot of Object.keys(LUCY_SLOTS)) assert.ok(cell(module, slot), slot)
      assert.ok(!module.includes('"lucide:x"'), 'the icon behind a slot is only listed when the game uses it')
      assert.match(module, /lucide: Lucide, ISC/)
      const lock = JSON.parse(await readFile(join(root, 'lucy-icons.lock.json'), 'utf8'))
      assert.deepEqual([...lock.order].sort(), ['lucide:heart', ...Object.values(LUCY_SLOTS)].sort())
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('shares one cell when the game uses the icon behind a slot', async () => {
    const root = await game({ 'src/A.luau': `local i = "lucide:x"` }, { lucy: true })
    try {
      await build({ config: join(root, 'lucy-icons.json'), sources: offlineSources, upload: fakeUploads().upload })
      const module = await readFile(join(root, 'src/Icons.luau'), 'utf8')
      assert.ok(cell(module, 'lucide:x'))
      assert.equal(cell(module, 'lucy:close'), cell(module, 'lucide:x'))
      const lock = JSON.parse(await readFile(join(root, 'lucy-icons.lock.json'), 'utf8'))
      assert.equal(lock.order.filter((n: string) => n === 'lucide:x').length, 1)
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('leaves them out with "lucy": false', async () => {
    const root = await game({ 'src/A.luau': `local i = "lucide:heart"` }, { lucy: false })
    try {
      const result = await build({ config: join(root, 'lucy-icons.json'), sources: offlineSources, upload: fakeUploads().upload })
      assert.deepEqual(result.icons, ['lucide:heart'])
      assert.ok(!(await readFile(join(root, 'src/Icons.luau'), 'utf8')).includes('lucy:'))
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })

  it('names every slot Lucy draws, each filled from a set:name icon', () => {
    assert.equal(Object.keys(LUCY_SLOTS).length, 8)
    for (const [slot, source] of Object.entries(LUCY_SLOTS)) {
      assert.match(slot, /^lucy:[a-z-]+$/)
      assert.ok(parseConfig({ include: [source] }), source)
    }
  })
})
