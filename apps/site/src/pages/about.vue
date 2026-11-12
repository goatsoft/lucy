<script setup lang="ts">
import { RouterLink } from 'vue-router'
import builtDark from '@/backgrounds/built-dark.aurora'
import builtLight from '@/backgrounds/built-light.aurora'
import heroDark from '@/backgrounds/hero-dark.aurora'
import heroLight from '@/backgrounds/hero-light.aurora'
import { SITE, useHead } from '@/head'

useHead({
  title: 'About',
  description: 'Why Lucy exists, the Roblox UI problems it solves, and who builds it at GOATsoft.',
})

const pillars = [
  {
    title: 'Native Roblox styling',
    text: 'Lucy styles through native Roblox StyleSheets instead of Luau loops. Hover states and light or dark theme swaps cost zero script time.',
  },
  {
    title: 'Instant updates, zero rebuilds',
    text: 'Change a stat or setting and only the exact UI property bound to it updates. No full rebuilds, no frame drops, and zero runtime dependencies.',
  },
  {
    title: 'Ready for every device',
    text: 'Desktop, console, tablet, and phone work from day one, with gamepad focus rings, 44px touch targets, hotkeys, server sync, plus guided tours.',
  },
] as const
</script>

<template>
  <main
    id="main-content"
    tabindex="-1"
  >
    <section class="relative isolate overflow-hidden px-6 pt-40 pb-20 text-center">
      <ThemedBackground
        :dark="heroDark"
        :light="heroLight"
      />
      <div class="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_55%_45%_at_50%_60%,var(--background)_35%,transparent_100%)] opacity-85" />
      <p class="eyebrow animate-rise">
        About
      </p>
      <h1 class="animate-rise mx-auto mt-4 max-w-3xl font-display text-heading font-semibold tracking-tight text-balance">
        Built to stop Roblox teams reinventing the UI wheel
      </h1>
      <p class="animate-rise mx-auto mt-6 max-w-2xl text-lead leading-8 text-pretty text-muted-foreground [animation-delay:120ms]">
        Lucy is an open UI and app framework by GOATsoft. It gives your game themed components, shared state, plus full controller and mobile input so you can focus on gameplay instead of UI plumbing.
      </p>
    </section>

    <section class="mx-auto max-w-4xl space-y-16 px-6 py-12">
      <div class="grid gap-10 md:grid-cols-2">
        <article class="rounded-2xl border border-border bg-surface p-7">
          <p class="eyebrow">
            Who is GOATsoft
          </p>
          <h2 class="mt-3 font-display text-2xl font-semibold tracking-tight text-foreground">
            Frontend craft brought to Roblox games
          </h2>
          <p class="mt-4 text-sm leading-7 text-pretty text-muted-foreground">
            <a
              :href="SITE.goatsoft"
              target="_blank"
              rel="noopener"
              class="font-medium text-primary underline decoration-primary/30 underline-offset-4 hover:decoration-primary"
            >GOATsoft</a>
            comes from years of building software and component libraries before bringing that same polish into Roblox: clean spacing, readable contrast, full controller support, with zero state spaghetti.
          </p>
          <p class="mt-4 text-sm leading-7 text-pretty text-muted-foreground">
            Alongside Lucy, we build open tooling for our projects, including the Aurora shader background engine and Gruff, the documentation framework behind this site.
          </p>
        </article>

        <article class="rounded-2xl border border-border bg-surface p-7">
          <p class="eyebrow">
            Why Lucy
          </p>
          <h2 class="mt-3 font-display text-2xl font-semibold tracking-tight text-foreground">
            Closing the Roblox UI gap
          </h2>
          <p class="mt-4 text-sm leading-7 text-pretty text-muted-foreground">
            Building Roblox UI usually leaves you with three rough options: wiring Instance cleanup loops by hand, adopting a heavy virtual tree framework, or grabbing a bare reactive library while still writing buttons, dialogs, gamepad focus, DataStore queues, and leaderboards yourself.
          </p>
          <p class="mt-4 text-sm leading-7 text-pretty text-muted-foreground">
            Lucy gives you the whole foundation out of the box: themed components, shared client and server state, layered scenes, Studio previews, plus coding agent tools.
          </p>
        </article>
      </div>

      <div class="grid gap-4 md:grid-cols-3">
        <article
          v-for="pillar in pillars"
          :key="pillar.title"
          class="rounded-2xl border border-border bg-surface/70 p-6"
        >
          <h3 class="font-display text-base font-semibold text-foreground">
            {{ pillar.title }}
          </h3>
          <p class="mt-2 text-sm leading-6 text-pretty text-muted-foreground">
            {{ pillar.text }}
          </p>
        </article>
      </div>

      <section class="relative isolate overflow-hidden rounded-2xl border border-border bg-surface p-8 md:p-10">
        <ThemedBackground
          :dark="builtDark"
          :light="builtLight"
        />
        <div
          aria-hidden="true"
          class="absolute inset-0 -z-10 bg-linear-to-r from-background/90 via-background/80 to-background/60"
        />
        <p class="eyebrow">
          Games
        </p>
        <h2 class="mt-3 font-display text-2xl font-semibold tracking-tight text-foreground">
          Built alongside real games
        </h2>
        <p class="mt-4 max-w-2xl text-sm leading-7 text-pretty text-muted-foreground">
          Lucy is not a library designed in a vacuum. After shipping <strong class="font-semibold text-foreground">Turf Heist</strong>, we started rebuilding <strong class="font-semibold text-foreground">Dance Lab</strong> and used it to pressure test every part of Lucy against real screens: live HUDs, shops, persistent audio settings, pause menus, weekly leaderboards and guided tutorials for new players.
        </p>
        <div class="mt-6 grid gap-4 sm:grid-cols-2">
          <div class="rounded-xl border border-border bg-background/75 p-5">
            <h3 class="font-display text-base font-semibold text-foreground">
              Turf Heist
            </h3>
            <p class="mt-1.5 text-sm leading-6 text-muted-foreground">
              Earlier GOATsoft Roblox action title that helped shape what our studio wanted from menus, HUD layouts and controller support.
            </p>
          </div>
          <div class="rounded-xl border border-border bg-background/75 p-5">
            <div class="flex items-center justify-between gap-2">
              <h3 class="font-display text-base font-semibold text-foreground">
                Dance Lab
              </h3>
              <span class="rounded-full border border-primary/30 bg-primary/10 px-2.5 py-0.5 font-mono text-[11px] text-primary">
                Case study soon
              </span>
            </div>
            <p class="mt-1.5 text-sm leading-6 text-muted-foreground">
              Currently in development with Lucy powering the whole client UI. A full Dance Lab case study will be published here when it goes live.
            </p>
          </div>
        </div>
        <div class="mt-8 flex flex-wrap gap-3">
          <Button
            :as="RouterLink"
            to="/docs/"
          >
            Read the docs <ILcChevronRight />
          </Button>
          <Button
            variant="glass"
            :as="RouterLink"
            to="/docs/development"
          >
            Contributing
          </Button>
          <Button
            variant="glass"
            as="a"
            :href="SITE.goatsoft"
            target="_blank"
            rel="noopener"
          >
            GOATsoft <ILcArrowUpRight />
          </Button>
        </div>
      </section>
    </section>
  </main>
</template>
