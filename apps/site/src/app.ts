import { createApp, createSSRApp } from 'vue'
import { createMemoryHistory, createRouter, createWebHistory } from 'vue-router'
import { routes } from 'vue-router/auto-routes'
import App from './App.vue'
import { createHead } from './head'
import '@fontsource-variable/fredoka'
import '@fontsource-variable/nunito'
import './main.css'

/** One app for both the prerender (memory history) and the browser (hydrating the same HTML). */
export function createSite(path: string) {
  // The dev server serves index.html as is, with no prerendered HTML to hydrate, so it mounts fresh.
  const app = import.meta.env.DEV && !import.meta.env.SSR ? createApp(App) : createSSRApp(App)
  const router = createRouter({
    history: import.meta.env.SSR ? createMemoryHistory() : createWebHistory(),
    routes,
    scrollBehavior: (to, _from, saved) => {
      const still = !import.meta.env.SSR && matchMedia('(prefers-reduced-motion: reduce)').matches
      return saved ?? (to.hash ? { el: to.hash, top: 96, behavior: still ? 'instant' : 'smooth' } : { top: 0 })
    },
  })
  app.use(router)
  const head = createHead(app, path)
  return { app, router, head }
}
