<script setup lang="ts">
import { RouterLink } from 'vue-router'
import { useHead } from '@/head'

useHead({ title: 'Not found', description: 'There is nothing at this address.' })
</script>

<template>
  <main
    id="main-content"
    tabindex="-1"
    class="relative isolate grid min-h-dvh place-items-center overflow-hidden px-6 text-center"
  >
    <div class="absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_top,color-mix(in_oklab,var(--primary)_22%,transparent),transparent_60%)]" />
    <div class="rounded-3xl border border-border bg-background/95 p-8 sm:p-12">
      <p class="eyebrow">
        404
      </p>
      <h1 class="mt-4 font-display text-5xl font-semibold tracking-tight text-balance sm:text-6xl">
        Page not found
      </h1>
      <p class="mx-auto mt-4 max-w-md text-lg text-pretty text-muted-foreground">
        There is no page at this address.
      </p>
      <div class="mt-9 flex flex-col justify-center gap-3 sm:flex-row">
        <Button
          :as="RouterLink"
          to="/"
        >
          <ILxHouseDuotone /> Home
        </Button>
        <Button
          variant="glass"
          :as="RouterLink"
          to="/docs/"
        >
          <ILxBookOpenDuotone /> Docs
        </Button>
      </div>
    </div>
  </main>
</template>
