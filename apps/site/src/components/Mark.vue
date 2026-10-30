<script setup lang="ts">
import mark from '@/assets/mark.svg?url'

/** The Lucy mark (placeholder until there is a brand pack). */
const props = defineProps<{ size: number }>()
</script>

<template>
  <img
    :src="mark"
    :width="props.size"
    :height="props.size"
    alt=""
    draggable="false"
  >
</template>
