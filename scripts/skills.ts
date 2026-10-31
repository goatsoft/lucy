/**
 * Builds the agent skills' reference files from docs/, so skills never drift
 * from the docs (the docs stay the one home for each topic).
 *
 *   node scripts/skills.ts           write plugins/lucy/skills/<skill>/references
 *   node scripts/skills.ts --check   change nothing; fail when anything is out of date
 *
 * Each skill mirrors the docs it takes under references/, keeping their paths,
 * so links between included pages work as they are. Links to pages a skill
 * does not include point at the website. SKILL.md files are written by hand,
 * except for blocks between `<!-- generated:<name> -->` and
 * `<!-- /generated:<name> -->`, which this script fills.
 */
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join, posix, relative } from 'node:path'

const ROOT = join(import.meta.dirname, '..')
const DOCS = join(ROOT, 'docs')
const SKILLS = join(ROOT, 'plugins', 'lucy', 'skills')
const SITE = 'https://lucy.goatsoft.io'
const HEADER = (doc: string) =>
  `<!-- Made by scripts/skills.ts from docs/${doc}. Edit the doc, not this file. -->\n`

/** Every docs page, relative to docs/, with "/" separators. ADRs are repo only. */
function allDocs(dir = DOCS, base = ''): string[] {
  const out: string[] = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = base ? `${base}/${entry.name}` : entry.name
    if (entry.isDirectory()) {
      if (path !== 'adr') out.push(...allDocs(join(dir, entry.name), path))
    } else if (entry.name.endsWith('.md')) {
      out.push(path)
    }
  }
  return out.sort()
}

// For people working on Lucy, not with it, and how to install the skills themselves.
const CONTRIBUTOR = new Set(['development.md', 'benchmarks.md', 'guide/agents.md'])
const ICONS = new Set(['guide/icons.md', 'components/icon.md'])
const DEBUG = new Set(['reference/devtools.md', 'stories.md', 'reference/store.md'])

const docs = allDocs()
const skills: Record<string, string[]> = {
  lucy: docs.filter(d => !CONTRIBUTOR.has(d) && d !== 'guide/icons.md'),
  'lucy-icons': docs.filter(d => ICONS.has(d)),
  'lucy-debug': docs.filter(d => DEBUG.has(d)),
}

interface Page {
  title: string
  description: string
  body: string
}

function readPage(doc: string): Page {
  const text = readFileSync(join(DOCS, doc), 'utf8')
  const match = text.match(/^---\n([\s\S]*?)\n---\n/)
  const meta: Record<string, string> = {}
  if (match) {
    for (const line of (match[1] as string).split('\n')) {
      const at = line.indexOf(':')
      if (at > 0) meta[line.slice(0, at).trim()] = line.slice(at + 1).trim().replace(/^"(.*)"$/, '$1')
    }
  }
  return {
    title: meta['title'] ?? doc,
    description: meta['description'] ?? '',
    // Example pictures and their markers are for the website only.
    body: (match ? text.slice(match[0].length).replace(/^\n+/, '') : text)
      .replace(/^<!-- preview\b[^>]*-->\n/gm, '')
      .replace(/^<figure class="example-preview[^"]*">.*<\/figure>\n\n?/gm, ''),
  }
}

/** The website address of a docs page. */
function siteUrl(doc: string, anchor: string): string {
  let route = doc.replace(/\.md$/, '')
  if (route === 'index') route = ''
  else if (route.endsWith('/index')) route = route.slice(0, -'index'.length)
  const url = `${SITE}/docs/${route}`
  return (url.endsWith('/') ? url : `${url}/`) + anchor
}

const problems: string[] = []

/**
 * Rewrites links to pages the skill leaves out, so every link still works: to
 * another skill's copy when one has the page (skills ship side by side in the
 * plugin), else to the website.
 */
function rewriteLinks(body: string, doc: string, included: Set<string>, skill: string): string {
  const from = posix.dirname(doc)
  // Skip fenced code: links there are examples, not links.
  return body
    .split(/(^```[\s\S]*?^```)/m)
    .map((part, i) =>
      i % 2 === 1
        ? part
        : part.replace(/\]\(([^)\s]+)\)/g, (whole, target: string) => {
            if (/^([a-z]+:|#)/.test(target)) return whole
            const [path, hash] = target.split('#') as [string, string | undefined]
            const anchor = hash ? `#${hash}` : ''
            const resolved = posix.normalize(posix.join(from, path))
            if (!resolved.endsWith('.md') || resolved.startsWith('..')) {
              problems.push(`docs/${doc}: link to "${target}" is not a docs page`)
              return whole
            }
            if (!docs.includes(resolved)) {
              problems.push(`docs/${doc}: link to "${target}" has no page`)
              return whole
            }
            if (included.has(resolved)) return whole
            const other = Object.keys(skills).find(name => name !== skill && skills[name]?.includes(resolved))
            if (other) {
              const here = posix.dirname(posix.join(skill, 'references', doc))
              return `](${posix.relative(here, posix.join(other, 'references', resolved))}${anchor})`
            }
            return `](${siteUrl(resolved, anchor)})`
          }),
    )
    .join('')
}

/** name -> what the file should hold. */
const wanted = new Map<string, string>()

for (const [skill, pages] of Object.entries(skills)) {
  const included = new Set(pages)
  for (const doc of pages) {
    const page = readPage(doc)
    wanted.set(join(SKILLS, skill, 'references', doc), HEADER(doc) + rewriteLinks(page.body, doc, included, skill))
  }
}

// Blocks in SKILL.md files.
function linkList(skill: string, pages: string[]): string {
  return pages
    .map(doc => {
      const page = readPage(doc)
      return `- [${page.title}](references/${doc})${page.description ? `: ${page.description}` : ''}`
    })
    .join('\n')
}

const lucyPages = skills['lucy'] as string[]
const ORDER = ['index.md', 'architecture.md', 'reactivity.md', 'components/index.md', 'guide/', 'stories.md', 'reference/']
const rank = (doc: string) => {
  const at = ORDER.findIndex(p => (p.endsWith('/') ? doc.startsWith(p) : doc === p))
  return at === -1 ? ORDER.length : at
}
const blocks: Record<string, Record<string, string>> = {
  lucy: {
    components: linkList(
      'lucy',
      lucyPages.filter(d => d.startsWith('components/') && d !== 'components/index.md'),
    ),
    // Read in this order: start, how it fits, the guides, then reference pages.
    guides: linkList(
      'lucy',
      lucyPages
        .filter(d => !d.startsWith('components/') || d === 'components/index.md')
        .sort((a, b) => rank(a) - rank(b) || a.localeCompare(b)),
    ),
  },
}

for (const [skill, named] of Object.entries(blocks)) {
  const file = join(SKILLS, skill, 'SKILL.md')
  if (!existsSync(file)) {
    problems.push(`${relative(ROOT, file)} is missing`)
    continue
  }
  let text = readFileSync(file, 'utf8')
  for (const [name, content] of Object.entries(named)) {
    const re = new RegExp(`(<!-- generated:${name} -->\\n)[\\s\\S]*?(<!-- /generated:${name} -->)`)
    if (!re.test(text)) {
      problems.push(`${relative(ROOT, file)} has no generated:${name} block`)
      continue
    }
    text = text.replace(re, `$1${content}\n$2`)
  }
  wanted.set(file, text)
}

if (problems.length > 0) {
  process.stderr.write(problems.map(p => `skills: ${p}\n`).join(''))
  process.exit(1)
}

// Generated files that should no longer be there.
function generatedFiles(dir: string): string[] {
  if (!existsSync(dir)) return []
  const out: string[] = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) out.push(...generatedFiles(path))
    else if (readFileSync(path, 'utf8').startsWith('<!-- Made by scripts/skills.ts')) out.push(path)
  }
  return out
}
const stale = generatedFiles(SKILLS).filter(f => !wanted.has(f))

const check = process.argv.includes('--check')
const outdated: string[] = []
for (const [file, text] of wanted) {
  const before = existsSync(file) ? readFileSync(file, 'utf8') : undefined
  if (before === text) continue
  outdated.push(relative(ROOT, file))
  if (!check) {
    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(file, text)
  }
}
for (const file of stale) {
  outdated.push(`${relative(ROOT, file)} (no longer made)`)
  if (!check) rmSync(file)
}

if (check) {
  if (outdated.length > 0) {
    process.stderr.write(
      `The skills are out of date with docs/. Run node scripts/skills.ts:\n${outdated.map(f => `  ${f}\n`).join('')}`,
    )
    process.exit(1)
  }
  process.stdout.write(`skills: ${wanted.size} files up to date\n`)
} else {
  process.stdout.write(`skills: ${outdated.length} of ${wanted.size} files written\n`)
}
