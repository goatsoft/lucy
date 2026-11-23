<script setup lang="ts">
import { RouterLink } from 'vue-router'
import heroDark from '@/backgrounds/hero-dark.aurora'
import heroLight from '@/backgrounds/hero-light.aurora'
import CaseStudy from '@/content/case-study-dance-lab.md'
import { useHead } from '@/head'

useHead({
  title: 'Dance Lab case study',
  description: 'How Dance Lab, a dance battle rhythm game for phone, desktop and console, runs its whole UI on Lucy.',
})
</script>

<template>
  <main
    id="main-content"
    tabindex="-1"
  >
    <section class="relative isolate overflow-hidden px-6 pt-40 pb-16 text-center">
      <ThemedBackground
        :dark="heroDark"
        :light="heroLight"
      />
      <div class="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_55%_45%_at_50%_60%,var(--background)_35%,transparent_100%)] opacity-85" />
      <p class="eyebrow animate-rise">
        Case study
      </p>
      <h1 class="animate-rise mx-auto mt-4 max-w-3xl font-display text-heading font-semibold tracking-tight text-balance">
        Dance Lab
      </h1>
      <p class="animate-rise mx-auto mt-6 max-w-2xl text-lead leading-8 text-pretty text-muted-foreground [animation-delay:120ms]">
        A dance battle rhythm game for phone, desktop and console, with its whole UI on Lucy.
      </p>
      <p class="animate-rise mt-6 [animation-delay:200ms]">
        <span class="rounded-full border border-primary/30 bg-primary/10 px-3 py-1 font-mono text-xs text-primary">
          In development
        </span>
      </p>
    </section>

    <article class="prose case-study mx-auto max-w-3xl px-6 pb-16">
      <CaseStudy />
    </article>

    <aside class="mx-auto max-w-3xl px-6 pb-10">
      <p
        id="screenshot-note"
        class="scroll-mt-28 border-t border-border pt-6 text-sm leading-6 text-pretty text-muted-foreground"
      >
        <sup class="mr-1 font-mono text-primary">1</sup>
        Dance Lab is still in heavy development. The screenshots show the game as it is today, and the final screens may look different.
      </p>
    </aside>

    <section class="mx-auto flex max-w-3xl flex-wrap gap-3 px-6 pb-24">
      <Button
        :as="RouterLink"
        to="/docs/"
      >
        Get started with Lucy <ILcChevronRight />
      </Button>
      <Button
        variant="glass"
        :as="RouterLink"
        to="/about"
      >
        About Lucy
      </Button>
    </section>
  </main>
</template>
