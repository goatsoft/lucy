import type { DocsOptions } from '@goatsoft/gruff/vue'
import { breadcrumbTrail, navGroups } from '@goatsoft/gruff/vue'
import IconCheck from '~icons/lucide/check'
import IconChevronDown from '~icons/lucide/chevron-down'
import IconChevronLeft from '~icons/lucide/chevron-left'
import IconChevronRight from '~icons/lucide/chevron-right'
import IconCopy from '~icons/lucide-extended/copy-duotone'
import IconSearch from '~icons/lucide-extended/search-duotone'
import { useHead } from '@/head'
import * as data from 'virtual:gruff'

/** The docs sidebar: groups by route, each sorted by frontmatter `order`, then route. */
export const nav = navGroups(data.pages, [
  { title: 'Get started', match: (r) => r === '/docs' || r.startsWith('/docs/guide/') },
  { title: 'Components', match: (r) => r === '/docs/components' || r.startsWith('/docs/components/') },
  { title: 'Recipes', match: (r) => r.startsWith('/docs/recipes') },
  { title: 'Reference', match: (r) => r === '/docs/reactivity' || r === '/docs/architecture' || r === '/docs/stories' || r === '/docs/benchmarks' || r === '/docs/known-issues' || r.startsWith('/docs/reference/') },
  { title: 'Contributing', match: (r) => r === '/docs/development' },
])

/** What the site gives gruff's docs components (`app.use(gruffDocs(docs))`). */
export const docs: DocsOptions = {
  data,
  nav,
  // Docs, then the pages above this one; the layout adds the page itself.
  breadcrumbs: (route) => breadcrumbTrail(data.pages, route),
  useHead,
  searchHint: 'Guides, components and architecture.',
  icons: { check: IconCheck, copy: IconCopy, chevronDown: IconChevronDown, chevronLeft: IconChevronLeft, chevronRight: IconChevronRight, search: IconSearch },
}
