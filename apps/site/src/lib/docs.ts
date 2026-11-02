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

// The basics: install, screens, state and input.
const getStarted = new Set(['/docs', '/docs/guide/scenes', '/docs/guide/app-state', '/docs/guide/actions'])
// Past the basics: your own components and logic, previews, agents.
const goFurther = new Set(['/docs/guide/components', '/docs/guide/composables', '/docs/stories', '/docs/guide/agents'])
const reference = new Set(['/docs/reactivity', '/docs/architecture', '/docs/benchmarks', '/docs/known-issues'])

/**
 * The docs sidebar, in the order a game is built: the basics, the rest of the guides,
 * the components, whole screens to copy, then going further and the reference.
 * Groups must not overlap; each is sorted by frontmatter `order`, then route.
 */
export const nav = navGroups(data.pages, [
  { title: 'Get started', match: (r) => getStarted.has(r) },
  { title: 'Build your game', match: (r) => r.startsWith('/docs/guide/') && !getStarted.has(r) && !goFurther.has(r) },
  { title: 'Components', match: (r) => r === '/docs/components' || r.startsWith('/docs/components/') },
  { title: 'Recipes', match: (r) => r.startsWith('/docs/recipes') },
  { title: 'Go further', match: (r) => goFurther.has(r) },
  { title: 'Reference', match: (r) => reference.has(r) || r.startsWith('/docs/reference/') },
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
