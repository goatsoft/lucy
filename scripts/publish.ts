/**
 * Publishes every public npm package under libs/ whose version isn't on npm yet, then tags it
 * and creates its GitHub Release from its CHANGELOG. Runs only in release.yml, which has the
 * `npm` environment and `id-token: write`. Same flow as Aurora's.
 *
 * Each package is packed with pnpm (so `prepack` adds the LICENSE) and the tarball is published
 * with npm's own CLI, which authenticates through npm trusted publishing: no token, provenance
 * included. `--dry-run` packs and runs `npm publish --dry-run` instead, and skips the tags and
 * releases, so it can run anywhere.
 */
import { execFileSync } from 'node:child_process'
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

interface Manifest {
  name: string
  version: string
  private?: boolean
}

const root = resolve(import.meta.dirname, '..')
const dryRun = process.argv.includes('--dry-run')
/** npm's CLI added trusted publishing (OIDC) in 11.5.1. */
const MIN_NPM = [11, 5, 1]

const log = (message: string) => process.stdout.write(`${message}\n`)
const run = (command: string, args: string[], cwd = root) =>
  execFileSync(command, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] }).trim()

// The pnpm running this script (npm_execpath), so its pinned version packs too.
const pnpmPath = process.env['npm_execpath']
const pnpm = (args: string[], cwd: string) =>
  pnpmPath ? run(process.execPath, [pnpmPath, ...args], cwd) : run('pnpm', args, cwd)

if (!dryRun && !process.env['GITHUB_ACTIONS']) {
  throw new Error('Only release.yml publishes (so every version has provenance). Use --dry-run to check locally.')
}
function compareVersions(a: number[], b: number[]): number {
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const difference = (a[i] ?? 0) - (b[i] ?? 0)
    if (difference) return difference
  }
  return 0
}
const npmVersion = run('npm', ['--version']).split('.').map(part => parseInt(part, 10))
if (!dryRun && compareVersions(npmVersion, MIN_NPM) < 0) {
  throw new Error(`npm ${npmVersion.join('.')} can't use trusted publishing; it needs ${MIN_NPM.join('.')} or later.`)
}

/** Every public workspace package under libs/. */
const packages = readdirSync(join(root, 'libs')).flatMap(dir => {
  const file = join(root, 'libs', dir, 'package.json')
  if (!existsSync(file)) return []
  const manifest = JSON.parse(readFileSync(file, 'utf8')) as Manifest
  return manifest.private ? [] : [{ dir: join(root, 'libs', dir), ...manifest }]
})

async function published(name: string, version: string): Promise<boolean> {
  const response = await fetch(`https://registry.npmjs.org/${name}/${version}`)
  if (response.status === 404) return false
  if (!response.ok) throw new Error(`npm registry: ${response.status} for ${name}@${version}`)
  return true
}

/** The CHANGELOG section for `version`, without its heading. */
function releaseNotes(dir: string, name: string, version: string): string {
  const file = join(dir, 'CHANGELOG.md')
  const changelog = existsSync(file) ? readFileSync(file, 'utf8') : ''
  const section = changelog.split(/^## /m).find(part => part.startsWith(`${version}\n`))
  const body = section?.slice(version.length).trim() ?? 'See the CHANGELOG.'
  return `${body}\n\nInstall: \`npm install --save-dev ${name}\` · [npm](https://www.npmjs.com/package/${name}/v/${version})\n`
}

const work = mkdtempSync(join(tmpdir(), 'lucy-publish-'))
const released: typeof packages = []
try {
  for (const pkg of packages) {
    const tag = `${pkg.name}@${pkg.version}`
    if (await published(pkg.name, pkg.version)) {
      log(`${tag} is already on npm`)
      continue
    }
    pnpm(['pack', '--pack-destination', work], pkg.dir)
    const tarball = join(work, `${pkg.name.slice(1).replace('/', '-')}-${pkg.version}.tgz`)
    // npm's registry for the scope too, so a scope mapping in someone's .npmrc can't send it elsewhere.
    const scope = pkg.name.slice(0, pkg.name.indexOf('/'))
    run('npm', ['publish', tarball, `--${scope}:registry=https://registry.npmjs.org/`, '--access', 'public', '--provenance', ...(dryRun ? ['--dry-run'] : [])])
    log(`${dryRun ? 'Would publish' : 'Published'} ${tag}`)
    released.push(pkg)
  }

  if (!dryRun) {
    const sha = process.env['GITHUB_SHA'] ?? run('git', ['rev-parse', 'HEAD'])
    for (const pkg of released) {
      const tag = `${pkg.name}@${pkg.version}`
      const notes = join(work, `${pkg.name.slice(1).replace('/', '-')}.md`)
      writeFileSync(notes, releaseNotes(pkg.dir, pkg.name, pkg.version))
      // The Luau package's own releases stay "latest"; npm tools never take it over.
      run('gh', ['release', 'create', tag, '--target', sha, '--title', tag, '--notes-file', notes, '--latest=false'])
      log(`Released ${tag} on GitHub`)
    }
  }
} finally {
  rmSync(work, { recursive: true, force: true })
}
log(
  released.length
    ? `\n${released.length} package${released.length === 1 ? '' : 's'} ${dryRun ? 'would be ' : ''}published.`
    : '\nNothing to publish.',
)
