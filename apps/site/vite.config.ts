import { readdirSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { gruff } from '@goatsoft/gruff'
import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import AutoImport from 'unplugin-auto-import/vite'
import IconsResolver from 'unplugin-icons/resolver'
import Icons from 'unplugin-icons/vite'
import Components from 'unplugin-vue-components/vite'
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

export default defineConfig({
  plugins: [
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
      resolvers: [IconsResolver({ prefix: 'i', alias: { hg: 'hugeicons', si: 'simple-icons' } })],
    }),
    Icons({ compiler: 'vue3', scale: 1 }),
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
