import type { InjectionKey, Ref } from 'vue'
import { inject, onMounted, onScopeDispose, provide, ref } from 'vue'

export type ThemePreference = 'system' | 'light' | 'dark'

interface SitePreferences {
  light: Ref<boolean>
  theme: Ref<ThemePreference>
  setTheme: (theme: ThemePreference) => void
}
const key: InjectionKey<SitePreferences> = Symbol('site preferences')
const read = (name: string) => {
  try {
    return localStorage.getItem(name)
  } catch {
    return null
  }
}
const write = (name: string, value: string) => {
  try {
    localStorage.setItem(name, value)
  } catch { /* Preferences still work without storage. */ }
}

export function provideSitePreferences() {
  const light = ref(false)
  const theme = ref<ThemePreference>('system')
  const applyTheme = () => {
    light.value = theme.value === 'light' || (theme.value === 'system' && matchMedia('(prefers-color-scheme: light)').matches)
    document.documentElement.dataset['theme'] = light.value ? 'light' : 'dark'
    for (const meta of document.querySelectorAll<HTMLMetaElement>('meta[name="theme-color"]')) meta.content = light.value ? '#ffffff' : '#09090b'
  }
  const preferences = {
    light,
    theme,
    setTheme(value: ThemePreference) {
      theme.value = value
      write('lucy:theme', value)
      applyTheme()
    },
  }
  let cleanup: (() => void) | undefined
  onMounted(() => {
    const media = matchMedia('(prefers-color-scheme: light)')
    const saved = read('lucy:theme')
    theme.value = saved === 'light' || saved === 'dark' ? saved : 'system'
    applyTheme()
    media.addEventListener('change', applyTheme)
    cleanup = () => media.removeEventListener('change', applyTheme)
  })
  onScopeDispose(() => cleanup?.())
  provide(key, preferences)
  return preferences
}

export function useSitePreferences(): SitePreferences {
  return inject(key, () => ({ light: ref(false), theme: ref<ThemePreference>('system'), setTheme: () => undefined }), true)
}
