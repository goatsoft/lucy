<script setup lang="ts">
import type { AuroraSource } from '@goatsoft/aurora'
import { AuroraBackground } from '@goatsoft/aurora-vue'
import { onMounted, ref } from 'vue'
import { useSitePreferences } from '@/lib/preferences'

/**
 * An Aurora background with a light and a dark version, filling its positioned parent.
 * Both are in the server HTML and CSS shows the one for the theme, so the first paint is
 * right; once mounted, only the current theme's stays, so only one renders.
 */
const props = defineProps<{
  dark: AuroraSource
  /** Defaults to the dark one. */
  light?: AuroraSource
  /** Where pointer interactions are read from, when the background has any. */
  interactionTarget?: HTMLElement | undefined
}>()

const { light: isLight } = useSitePreferences()
const mounted = ref(false)
onMounted(() => {
  mounted.value = true
})
</script>

<template>
  <div
    v-if="!props.light"
    class="pointer-events-none absolute inset-0 -z-10"
  >
    <AuroraBackground
      :src="props.dark"
      :interaction-target="props.interactionTarget"
    />
  </div>
  <template v-else>
    <div
      v-if="!mounted || !isLight"
      class="pointer-events-none absolute inset-0 -z-10 hidden dark:block"
    >
      <AuroraBackground
        :src="props.dark"
        :interaction-target="props.interactionTarget"
      />
    </div>
    <div
      v-if="!mounted || isLight"
      class="pointer-events-none absolute inset-0 -z-10 dark:hidden"
    >
      <AuroraBackground
        :src="props.light"
        :interaction-target="props.interactionTarget"
      />
    </div>
  </template>
</template>
