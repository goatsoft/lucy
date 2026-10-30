<script setup lang="ts">
import { SITE } from '@/head'

const columns = [
  {
    title: 'Docs',
    links: [
      { label: 'Get started', to: '/docs' },
      { label: 'Components', to: '/docs/components' },
      { label: 'Architecture', to: '/docs/architecture' },
      { label: 'Contributing', to: '/docs/development' },
    ],
  },
  {
    title: 'Project',
    links: [
      { label: 'GitHub', href: SITE.repo },
      { label: 'Wally package', href: SITE.wally },
      { label: 'Issues', href: `${SITE.repo}/issues` },
      { label: 'Decisions (ADRs)', href: `${SITE.repo}/tree/main/docs/adr` },
    ],
  },
]
</script>

<template>
  <footer class="relative mt-24 border-t border-border">
    <div class="mx-auto grid max-w-6xl gap-12 px-6 py-16 md:grid-cols-[1.5fr_1fr_1fr]">
      <div>
        <RouterLink
          to="/"
          class="inline-flex items-center gap-2.5"
          aria-label="Lucy home"
        >
          <Mark :size="28" />
          <span class="font-display text-xl font-semibold tracking-tight text-foreground">Lucy</span>
        </RouterLink>
        <p class="mt-4 max-w-sm text-sm text-pretty text-muted-foreground">
          {{ SITE.description }}
        </p>
      </div>
      <div
        v-for="column in columns"
        :key="column.title"
      >
        <p class="font-mono text-[11px] tracking-[0.18em] text-muted-foreground/80 uppercase">
          {{ column.title }}
        </p>
        <ul class="mt-4 space-y-2.5 text-sm">
          <li
            v-for="link in column.links"
            :key="link.label"
          >
            <RouterLink
              v-if="'to' in link"
              :to="link.to"
              class="text-muted-foreground transition-colors hover:text-foreground"
            >
              {{ link.label }}
            </RouterLink>
            <a
              v-else
              :href="link.href"
              target="_blank"
              rel="noopener"
              class="text-muted-foreground transition-colors hover:text-foreground"
            >{{ link.label }}</a>
          </li>
        </ul>
      </div>
    </div>
    <div class="mx-auto flex max-w-6xl flex-col gap-2 border-t border-border px-6 py-6 text-xs text-muted-foreground sm:flex-row sm:justify-between">
      <p>
        MIT ·
        <a
          :href="`${SITE.repo}/blob/main/LICENSE`"
          target="_blank"
          rel="noopener"
          class="underline decoration-border underline-offset-4 hover:text-foreground"
        >Licence</a>
      </p>
      <p>Made by GOATsoft</p>
    </div>
  </footer>
</template>
