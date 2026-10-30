import { createSite } from './app'

// Built pages get their icons from the prerendered <head>; the dev server serves index.html without them.
if (import.meta.env.DEV) {
  document.head.append(Object.assign(document.createElement('link'), { rel: 'icon', href: '/favicon-32.png' }))
}

// gruff starts this after first paint; `gruff:hydrated` replays a button pressed before then.
const { app, router } = createSite(location.pathname)
void router.isReady().then(() => {
  app.mount('#app')
  dispatchEvent(new Event('gruff:hydrated'))
})
