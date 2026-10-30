import type { PageInfo } from '@goatsoft/gruff'
import { pages } from 'virtual:gruff'

export interface NavGroup {
  title: string
  items: PageInfo[]
}

/** The docs sidebar: groups by route, each sorted by frontmatter `order`, then title. */
const GROUPS: { title: string, match: (route: string) => boolean }[] = [
  { title: 'Get started', match: (r) => r === '/docs' || r.startsWith('/docs/guide/') },
  { title: 'Reference', match: (r) => r === '/docs/reactivity' || r === '/docs/components' || r === '/docs/architecture' || r.startsWith('/docs/reference/') },
  { title: 'Contributing', match: (r) => r === '/docs/development' },
]

const byOrder = (a: PageInfo, b: PageInfo) => (a.order ?? 1e9) - (b.order ?? 1e9) || a.route.localeCompare(b.route)

export const nav: NavGroup[] = GROUPS.map(({ title, match }) => ({ title, items: pages.filter((p) => match(p.route)).sort(byOrder) }))
  .filter((group) => group.items.length)

/** Every page in sidebar order, for previous / next links. */
export const sequence = nav.flatMap((group) => group.items)
