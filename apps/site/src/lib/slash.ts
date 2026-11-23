/**
 * `/docs/guide/scenes#setup` → `/docs/guide/scenes/#setup`. GitHub Pages serves every page from
 * its folder, so a link without the trailing slash costs a redirect, and the canonical address and
 * the sitemap both end in one. Files (`/og.png`) and paths that already end in a slash stay as they are.
 */
export function withSlash(location: string): string {
  const end = location.search(/[?#]/)
  const path = end < 0 ? location : location.slice(0, end)
  if (path.endsWith('/') || /\.[a-z\d]+$/i.test(path)) return location
  return `${path}/${location.slice(path.length)}`
}
