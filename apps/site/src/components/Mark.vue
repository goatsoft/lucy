<script setup lang="ts">
import head from '@/assets/lucy-head-256.webp?url'

/** Lucy herself: the mascot's head, linework restored (assets/brand). */
const props = defineProps<{ size: number }>()
</script>

<template>
  <img
    :src="head"
    :width="Math.round(props.size * 0.886)"
    :height="props.size"
    alt=""
    draggable="false"
    class="object-contain"
  >
</template>
