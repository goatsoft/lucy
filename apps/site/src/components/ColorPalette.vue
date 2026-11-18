<script setup lang="ts">
import { palette } from '@/lib/palette'

/** The base colours (`baseColor`), shown apart from the hues. */
const BASES = new Set(['slate', 'gray', 'zinc', 'neutral', 'stone', 'mauve', 'olive', 'mist', 'taupe'])

const props = defineProps<{
  /** `hues` (the default) or `bases` */
  show?: 'hues' | 'bases'
}>()

const rows = computed(() => palette.filter((hue) => BASES.has(hue.name) === (props.show === 'bases')))
const shades = computed(() => palette[0]?.shades.map((s) => s.shade) ?? [])

const copied = ref<string>()
let timer: ReturnType<typeof setTimeout> | undefined
async function copy(token: string) {
  await navigator.clipboard.writeText(`$${token}`)
  copied.value = token
  clearTimeout(timer)
  timer = setTimeout(() => (copied.value = undefined), 1200)
}
</script>

<template>
  <div class="not-prose my-6 overflow-x-auto">
    <div
      class="grid min-w-[40rem] items-center gap-x-1.5 gap-y-2"
      :style="{ gridTemplateColumns: `5.5rem repeat(${shades.length}, minmax(0, 1fr))` }"
    >
      <span />
      <span
        v-for="shade in shades"
        :key="shade"
        class="text-center text-xs text-muted-foreground"
      >{{ shade }}</span>
      <template
        v-for="hue in rows"
        :key="hue.name"
      >
        <span class="text-sm font-medium capitalize">{{ hue.name }}</span>
        <button
          v-for="s in hue.shades"
          :key="s.token"
          type="button"
          class="relative aspect-square w-full cursor-pointer rounded-md outline-offset-2 ring-1 ring-black/10 ring-inset focus-visible:outline-2 focus-visible:outline-ring dark:ring-white/10"
          :style="{ backgroundColor: s.hex }"
          :title="`$${s.token}  ${s.hex}  oklch(${s.oklch.join(' ')})`"
          :aria-label="`Copy $${s.token}`"
          @click="copy(s.token)"
        >
          <span
            v-if="copied === s.token"
            class="absolute inset-0 grid place-items-center rounded-md bg-black/60 text-[0.625rem] font-medium text-white"
          >Copied</span>
        </button>
      </template>
    </div>
  </div>
</template>
