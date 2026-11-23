<script setup lang="ts">
import { computed } from 'vue'

/**
 * A screenshot with a caption saying what it shows and on which device. Phone shots
 * sit in a PhoneFrame.
 */
const props = defineProps<{
  src: string
  alt: string
  caption: string
  device: 'console' | 'desktop' | 'phone' | 'tablet'
  /** The screenshot's shape for a phone frame (CSS aspect-ratio), when not 16:9. */
  aspect?: string
  /** A note on the page about the picture (`#id`), cited after the caption. */
  note?: string
}>()

const DEVICES = { console: 'Console', desktop: 'Desktop', phone: 'Phone', tablet: 'Tablet' } as const
const label = computed(() => DEVICES[props.device])
</script>

<template>
  <figure class="case-figure">
    <PhoneFrame
      v-if="props.device === 'phone'"
      v-bind="props.aspect ? { aspect: props.aspect } : {}"
    >
      <img
        :src="props.src"
        :alt="props.alt"
        loading="lazy"
      >
    </PhoneFrame>
    <img
      v-else
      :src="props.src"
      :alt="props.alt"
      loading="lazy"
    >
    <figcaption>
      <span>
        {{ props.caption }}<sup
          v-if="props.note"
          class="case-cite"
        ><a
          :href="props.note"
          aria-label="About this picture"
        >1</a></sup>
      </span>
      <span class="case-device">{{ label }}</span>
    </figcaption>
  </figure>
</template>
