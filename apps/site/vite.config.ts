import { existsSync, readFileSync, readdirSync, realpathSync, statSync } from 'node:fs'
import { dirname, extname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import aurora from '@goatsoft/aurora-unplugin/vite'
import { gruff } from '@goatsoft/gruff'
import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import AutoImport from 'unplugin-auto-import/vite'
import IconsResolver from 'unplugin-icons/resolver'
import Icons from 'unplugin-icons/vite'
import Components from 'unplugin-vue-components/vite'
import type { Plugin } from 'vite'
import { defineConfig, searchForWorkspaceRoot } from 'vite'
import { VueRouterAutoImports } from 'vue-router/unplugin'
import VueRouter from 'vue-router/vite'

const here = fileURLToPath(new URL('.', import.meta.url))
const root = searchForWorkspaceRoot(here)
const docs = join(root, 'docs')
const REPO = 'https://github.com/goatsoft/lucy'

/** Decision records stay in the repo for contributors; links to them go to GitHub. */
const internal = join(docs, 'adr')

/** `docs/components.md` → `/docs/components`; a folder's `index.md` or `README.md` is the folder. */
function route(file: string): string | undefined {
  if (!file.startsWith(`${docs}/`) || !file.endsWith('.md') || file.startsWith(`${internal}/`)) return undefined
  const path = relative(docs, file).replace(/\.md$/, '').replace(/(^|\/)(index|README)$/, '')
  return `/docs${path ? `/${path}` : ''}`
}

function pages(dir = docs): { file: string, route: string }[] {
  return readdirSync(dir).flatMap((name) => {
    const file = join(dir, name)
    if (statSync(file).isDirectory()) return pages(file)
    const path = route(file)
    return path ? [{ file, route: path }] : []
  })
}

/**
 * Resolves Aurora's npm packages the way Node does. This site turns on the `@goatsoft/source`
 * condition so workspace packages (gruff) load from source, but Aurora's published packages keep
 * that condition too, pointing at `src/` files they don't ship. For them, take the `import` file.
 */
function publishedAurora(): Plugin {
  const pattern = /^(@goatsoft\/(?:aurora[\w-]*|color))(\/.*)?$/
  return {
    name: 'lucy:published-aurora',
    enforce: 'pre',
    resolveId(id, importer) {
      const match = pattern.exec(id)
      if (!match) return null
      const pkg = match[1] as string
      const subpath = `.${match[2] ?? ''}`
      // From the real file: pnpm keeps a package's own dependencies beside it, not beside the link.
      const importerFile = importer && !importer.startsWith('\0') ? importer.split('?')[0] as string : undefined
      const from = importerFile && existsSync(importerFile) ? realpathSync(importerFile) : `${here}index.html`
      for (let dir = dirname(from); ; dir = dirname(dir)) {
        const manifest = join(dir, 'node_modules', pkg, 'package.json')
        if (existsSync(manifest)) {
          const exports = (JSON.parse(readFileSync(manifest, 'utf8')) as { exports?: Record<string, unknown> }).exports
          const entry = exports?.[subpath] as string | { import?: string, default?: string } | undefined
          const file = typeof entry === 'string' ? entry : entry?.import ?? entry?.default
          return file ? join(dirname(manifest), file) : null
        }
        if (dirname(dir) === dir) return null
      }
    },
  }
}

/**
 * Makes `vite preview` answer like GitHub Pages: a page path without its trailing slash
 * redirects to the folder, and an unknown path gets 404.html. Without this, preview
 * serves the home page for those paths and the page hydrates with mismatches.
 */
function pagesPreview(): Plugin {
  return {
    name: 'lucy:pages-preview',
    configurePreviewServer(server) {
      const dist = resolve(server.config.root, server.config.build.outDir)
      server.middlewares.use((req, res, next) => {
        const [path = '/', query] = (req.url ?? '/').split('?')
        if (extname(path)) return next()
        if (existsSync(join(dist, path, 'index.html'))) {
          if (path.endsWith('/')) return next()
          res.statusCode = 301
          res.setHeader('Location', `${path}/${query ? `?${query}` : ''}`)
          res.end()
          return
        }
        res.statusCode = 404
        res.setHeader('Content-Type', 'text/html')
        res.end(readFileSync(join(dist, '404.html')))
      })
    },
  }
}

export default defineConfig({
  plugins: [
    // Animated backgrounds: .aurora files, checked at build time, CSS fallback inlined.
    publishedAurora(),
    aurora(),
    // Pages from src/pages, and every Markdown file under the repo's docs/ as /docs/….
    VueRouter({
      root: here,
      routesFolder: [{ src: `${here}src/pages` }, { src: docs, path: 'docs/', exclude: ['**/adr/**'] }],
      extensions: ['.vue', '.md'],
      dts: process.env['VITEST'] ? false : `${here}src/typed-router.d.ts`,
      extendRoute(node) {
        if (node.fullPath.endsWith('/README')) node.path = node.path.replace(/\/?README$/, '')
      },
    }),
    ...gruff({
      root,
      route,
      pages: () => pages(),
      repoUrl: `${REPO}/blob/main/`,
      // Docs pages get the docs layout; snippets in src/content render bare, for the landing page.
      layout: (id) => (id.includes('/src/content/') ? null : 'DocPage'),
    }),
    // `LUCY_DEBUG_HYDRATION=1 pnpm site:build` explains hydration mismatches in the console.
    vue({ include: [/\.vue$/, /\.md$/], features: { prodHydrationMismatchDetails: process.env['LUCY_DEBUG_HYDRATION'] === '1' } }),
    tailwindcss(),
    AutoImport({
      imports: ['vue', VueRouterAutoImports, { '@vueuse/core': ['useEventListener', 'useWindowScroll'] }],
      dts: process.env['VITEST'] ? false : `${here}src/auto-imports.d.ts`,
      vueTemplate: true,
    }),
    Components({
      dirs: [`${here}src/components`],
      extensions: ['vue', 'md'],
      include: [/\.vue$/, /\.vue\?vue/, /\.md$/],
      dts: process.env['VITEST'] ? false : `${here}src/components.d.ts`,
      resolvers: [IconsResolver({ prefix: 'i', enabledCollections: ['lucide-extended', 'lucide', 'simple-icons'], alias: { lx: 'lucide-extended', lc: 'lucide', si: 'simple-icons' } })],
    }),
    Icons({ compiler: 'vue3', scale: 1 }),
    pagesPreview(),
  ],
  resolve: {
    conditions: ['@goatsoft/source'],
    alias: [
      { find: '~', replacement: root },
      { find: /^@\//, replacement: `${here}src/` },
    ],
  },
  ssr: { resolve: { conditions: ['@goatsoft/source'] }, noExternal: [/^@goatsoft\//, 'reka-ui'] },
  server: { fs: { allow: [root] } },
})
