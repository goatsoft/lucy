import { renderToString } from 'vue/server-renderer'
import { createSite } from './app'
import { headTags } from './head'

export { routes } from 'vue-router/auto-routes'

/** Renders one route to HTML for the prerender. */
export async function render(url: string): Promise<{ html: string, head: string, htmlAttrs: string }> {
  const { app, router, head } = createSite(url)
  await router.push(url)
  await router.isReady()
  const html = await renderToString(app)
  return { html, head: headTags(head), htmlAttrs: 'lang="en"' }
}
