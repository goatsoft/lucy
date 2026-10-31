/// <reference types="@goatsoft/aurora-unplugin/client" />

// For tools that don't understand .vue files (typescript-eslint). vue-tsc reads the real types.
declare module '*.vue' {
  import type { DefineComponent } from 'vue'

  const component: DefineComponent
  export default component
}
