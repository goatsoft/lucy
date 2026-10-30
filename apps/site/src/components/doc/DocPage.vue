<script setup lang="ts">
import type { TocEntry } from '@goatsoft/gruff'
import docsDark from '@/backgrounds/docs-dark.aurora'
import docsLight from '@/backgrounds/docs-light.aurora'
import ThemedBackground from '@/components/ThemedBackground.vue'
import { useHead } from '@/head'
import { breadcrumbs, nav, sequence } from '@/lib/docs'

/** The docs layout gruff wraps every page in: sidebar, the page, and "On this page". */
const props = defineProps<{ frontmatter: { title?: string, description?: string, toc?: TocEntry[] } }>()
const route = useRoute()
useHead({ title: () => props.frontmatter.title, description: () => props.frontmatter.description })

const here = computed(() => route.path.replace(/\/$/, '') || '/')
const index = computed(() => sequence.findIndex((p) => p.route === here.value))
const prev = computed(() => sequence[index.value - 1])
const next = computed(() => (index.value >= 0 ? sequence[index.value + 1] : undefined))
const trail = computed(() => breadcrumbs(here.value))
const menu = ref(false)
watch(here, () => (menu.value = false))
</script>

<template>
  <!-- The grid runs to the footer (its top margin is cancelled here and given back as the main
       column's padding), so the sticky sidebar stays put until the footer actually arrives. -->
  <div class="relative isolate mx-auto -mb-24 grid max-w-7xl gap-10 px-6 pt-28 lg:grid-cols-[15rem_minmax(0,1fr)] xl:grid-cols-[15rem_minmax(0,1fr)_13rem]">
    <!-- A band of digital rain across the top of every page, the full width of the window,
         fading out before the text starts. -->
    <div class="pointer-events-none absolute top-0 left-1/2 -z-10 h-96 w-screen -translate-x-1/2 mask-b-from-10% mask-b-to-100%">
      <ThemedBackground
        :dark="docsDark"
        :light="docsLight"
      />
    </div>
    <!-- Sticks below the nav and runs to the bottom of the window, scrolling on its own. -->
    <aside class="lg:sticky lg:top-28 lg:max-h-[calc(100dvh-7rem)] lg:self-start lg:overflow-y-auto lg:overscroll-contain lg:mask-b-from-[calc(100%-2.5rem)] lg:mask-b-to-100% lg:pb-10">
      <SearchDialog />
      <button
        class="mt-3 flex w-full items-center justify-between rounded-lg border border-border px-3 py-2 text-sm text-muted-foreground lg:hidden"
        :aria-expanded="menu"
        @click="menu = !menu"
      >
        Menu <ILcChevronDown
          class="size-4 transition-transform"
          :class="menu && 'rotate-180'"
        />
      </button>
      <nav
        class="mt-6 space-y-7 text-sm lg:block"
        :class="menu ? 'block' : 'hidden'"
        aria-label="Docs"
      >
        <div
          v-for="group in nav"
          :key="group.title"
        >
          <p class="mb-2 px-3 font-mono text-[11px] tracking-[0.18em] text-muted-foreground/80 uppercase">
            {{ group.title }}
          </p>
          <ul class="space-y-0.5">
            <li
              v-for="page in group.items"
              :key="page.route"
            >
              <RouterLink
                :to="page.route"
                class="relative block rounded-lg px-3 py-1.5 transition-colors"
                :class="page.route === here ? 'bg-white/6 font-medium text-foreground' : 'text-muted-foreground hover:text-foreground'"
              >
                <span
                  v-if="page.route === here"
                  class="absolute inset-y-1.5 left-0 w-0.5 rounded-full bg-linear-to-b from-spectrum-1 to-spectrum-2"
                />
                {{ page.sidebarTitle ?? page.title }}
              </RouterLink>
            </li>
          </ul>
        </div>
      </nav>
    </aside>

    <!-- At least as tall as the sidebar can be, so a short page doesn't push the sticky sidebar up and cut it off. -->
    <main
      id="main-content"
      tabindex="-1"
      class="min-w-0 pb-48 lg:min-h-[calc(100dvh-7rem)]"
    >
      <nav
        v-if="trail.length"
        aria-label="Breadcrumb"
        class="mb-6 text-sm"
      >
        <ol class="flex flex-wrap items-center gap-1.5 text-muted-foreground">
          <li
            v-for="crumb in trail"
            :key="crumb.route"
            class="flex items-center gap-1.5"
          >
            <RouterLink
              :to="`${crumb.route}/`"
              class="transition-colors hover:text-foreground"
            >
              {{ crumb.title }}
            </RouterLink>
            <ILcChevronRight
              aria-hidden="true"
              class="size-3.5 text-muted-foreground/60"
            />
          </li>
          <li
            aria-current="page"
            class="text-foreground"
          >
            {{ props.frontmatter.title }}
          </li>
        </ol>
      </nav>
      <article><slot /></article>
      <nav
        v-if="prev || next"
        class="mt-16 grid gap-3 border-t border-border pt-8 sm:grid-cols-2"
        aria-label="Pages"
      >
        <RouterLink
          v-if="prev"
          :to="prev.route"
          class="group rounded-xl border border-border p-4 transition-colors hover:border-primary/40"
        >
          <span class="text-xs text-muted-foreground">Previous</span>
          <span class="mt-1 flex items-center gap-1.5 font-medium"><ILcChevronLeft class="size-4 transition-transform group-hover:-translate-x-0.5" />{{ prev.title }}</span>
        </RouterLink>
        <RouterLink
          v-if="next"
          :to="next.route"
          class="group rounded-xl border border-border p-4 text-right transition-colors hover:border-primary/40 sm:col-start-2"
        >
          <span class="text-xs text-muted-foreground">Next</span>
          <span class="mt-1 flex items-center justify-end gap-1.5 font-medium">{{ next.title }}<ILcChevronRight class="size-4 transition-transform group-hover:translate-x-0.5" /></span>
        </RouterLink>
      </nav>
    </main>

    <DocToc
      :entries="props.frontmatter.toc ?? []"
      class="hidden xl:block"
    />
  </div>
</template>
