import type { PageInfo } from '@goatsoft/gruff'
import { pages } from 'virtual:gruff'

export interface NavGroup {
  title: string
  items: PageInfo[]
}

/** The docs sidebar: groups by route, each sorted by frontmatter `order`, then title. */
const GROUPS: { title: string, match: (route: string) => boolean }[] = [
  { title: 'Get started', match: (r) => r === '/docs' || r.startsWith('/docs/guide/') },
  { title: 'Components', match: (r) => r === '/docs/components' || r.startsWith('/docs/components/') },
  { title: 'Recipes', match: (r) => r.startsWith('/docs/recipes') },
  { title: 'Reference', match: (r) => r === '/docs/reactivity' || r === '/docs/architecture' || r === '/docs/stories' || r === '/docs/benchmarks' || r === '/docs/known-issues' || r.startsWith('/docs/reference/') },
  { title: 'Contributing', match: (r) => r === '/docs/development' },
]

const byOrder = (a: PageInfo, b: PageInfo) => (a.order ?? 1e9) - (b.order ?? 1e9) || a.route.localeCompare(b.route)

export const nav: NavGroup[] = GROUPS.map(({ title, match }) => ({ title, items: pages.filter((p) => match(p.route)).sort(byOrder) }))
  .filter((group) => group.items.length)

/** Every page in sidebar order, for previous / next links. */
export const sequence = nav.flatMap((group) => group.items)

export interface Crumb {
  title: string
  route: string
}

/**
 * The pages above a docs page, from the docs home down: for
 * `/docs/components/button` that is Docs, then Components, and for
 * `/docs/components` just Docs. The page itself is not included; the layout adds
 * it from its own title. Folders without a page of their own are left out. The
 * docs home gets no trail.
 */
export function breadcrumbs(route: string): Crumb[] {
  const parts = route.replace(/^\/docs\/?/, '').split('/').filter(Boolean)
  if (parts.length === 0) return []
  const trail: Crumb[] = [{ title: 'Docs', route: '/docs' }]
  for (let i = 1; i < parts.length; i++) {
    const path = `/docs/${parts.slice(0, i).join('/')}`
    const page = pages.find((p) => p.route === path)
    if (page) trail.push({ title: page.title, route: page.route })
  }
  return trail
}
