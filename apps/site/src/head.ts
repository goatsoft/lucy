import type { App, InjectionKey, MaybeRefOrGetter } from 'vue'
import { inject, toValue, watchEffect } from 'vue'

export const SITE = {
  name: 'Lucy',
  url: 'https://lucy.goatsoft.io',
  repo: 'https://github.com/goatsoft/lucy',
  wally: 'https://wally.run/package/goatsoft/lucy',
  goatsoft: 'https://goatsoft.io',
  description: 'One source of truth for your UI and app state. Change a value and only what shows it updates. Themed components that work with mouse, keyboard, gamepad and touch.',
}

export interface Head {
  title: string
  description: string
  path: string
}

const KEY: InjectionKey<Head> = Symbol('head')

/** A tiny head manager: pages set their title and description; SSR writes them, the client keeps them in sync. */
export function createHead(app: App, path: string): Head {
  const head: Head = { title: SITE.name, description: SITE.description, path }
  app.provide(KEY, head)
  return head
}

export function useHead(meta: { title?: MaybeRefOrGetter<string | undefined>, description?: MaybeRefOrGetter<string | undefined> }): void {
  const head = inject(KEY)
  if (!head) return
  watchEffect(() => {
    const title = toValue(meta.title)
    head.title = title ? `${title} · ${SITE.name}` : `${SITE.name}: a UI and app framework for Roblox`
    head.description = toValue(meta.description) ?? SITE.description
    if (typeof document !== 'undefined') {
      document.title = head.title
      document.querySelector('meta[name="description"]')?.setAttribute('content', head.description)
    }
  })
}

const escape = (s: string) => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')

/** The `<head>` tags for a rendered page. */
export function headTags(head: Head): string {
  // GitHub Pages serves each page as a folder, at its path with a trailing slash.
  const url = `${SITE.url}${head.path.replace(/\/?$/, '/')}`
  return [
    `<title>${escape(head.title)}</title>`,
    `<meta name="description" content="${escape(head.description)}">`,
    `<link rel="canonical" href="${url}">`,
    `<link rel="icon" href="/favicon.ico" sizes="48x48">`,
    `<link rel="icon" type="image/png" href="/favicon-32.png" sizes="32x32">`,
    `<link rel="apple-touch-icon" href="/apple-touch-icon.png">`,
    `<link rel="manifest" href="/manifest.webmanifest">`,
    `<meta property="og:type" content="website">`,
    `<meta property="og:site_name" content="${SITE.name}">`,
    `<meta property="og:title" content="${escape(head.title)}">`,
    `<meta property="og:description" content="${escape(head.description)}">`,
    `<meta property="og:url" content="${url}">`,
    `<meta property="og:image" content="${SITE.url}/og.png">`,
    `<meta name="twitter:card" content="summary_large_image">`,
  ].join('\n    ')
}
