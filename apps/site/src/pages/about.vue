<script setup lang="ts">
import { AuroraScene } from '@goatsoft/aurora-vue'
import { RouterLink } from 'vue-router'
import heroDark from '@/backgrounds/hero-dark.aurora'
import heroLight from '@/backgrounds/hero-light.aurora'
import panelGamesDark from '@/backgrounds/panel-games-dark.aurora'
import panelGamesLight from '@/backgrounds/panel-games-light.aurora'
import panelPillarDark from '@/backgrounds/panel-pillar-dark.aurora'
import panelPillarLight from '@/backgrounds/panel-pillar-light.aurora'
import { SITE, useHead } from '@/head'

useHead({
  title: 'About',
  description: 'Why Lucy exists, the Roblox UI problems it solves, and who builds it at GOATsoft.',
})

function movePanelLight(event: PointerEvent): void {
  const panel = event.currentTarget as HTMLElement
  const box = panel.getBoundingClientRect()
  panel.style.setProperty('--light-x', `${event.clientX - box.left}px`)
  panel.style.setProperty('--light-y', `${event.clientY - box.top}px`)
}

const pillars = [
  {
    title: 'Native Roblox styling',
    text: 'Style through Roblox StyleSheets instead of Luau loops. Hovers and theme swaps cost zero script time.',
  },
  {
    title: 'Instant updates, zero rebuilds',
    text: 'Update a value once and only its bound UI property changes. No full rebuilds, no frame drops, zero dependencies.',
  },
  {
    title: 'Ready for every device',
    text: 'Desktop, console, tablet, and phone work from day one with gamepad focus, touch targets, hotkeys, plus server sync.',
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
        Built so Roblox teams stop rebuilding the same UI
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
            comes from years of building software and component libraries before bringing that same polish into Roblox: clean spacing, readable contrast, full controller support, and clean state management.
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

      <AuroraScene name="about-pillars">
        <div class="grid gap-4 md:grid-cols-3">
          <article
            v-for="pillar in pillars"
            :key="pillar.title"
            class="group relative isolate overflow-hidden rounded-2xl border border-border bg-surface p-6 [--light-x:0px] [--light-y:0px] shadow-[inset_0_1px_0_0_color-mix(in_oklab,white_8%,transparent)] transition duration-300 hover:border-primary/40"
            @pointermove="movePanelLight"
          >
            <ThemedBackground
              :dark="panelPillarDark"
              :light="panelPillarLight"
            />
            <div
              aria-hidden="true"
              class="absolute inset-0 -z-10 bg-linear-to-t from-background/90 via-background/60 to-background/20"
            />
            <div
              aria-hidden="true"
              class="absolute inset-0 -z-10 bg-[radial-gradient(circle_14rem_at_var(--light-x)_var(--light-y),color-mix(in_oklab,var(--primary)_18%,transparent),transparent_65%)] opacity-0 transition-opacity duration-300 group-hover:opacity-100"
            />
            <h3 class="font-display text-base font-semibold text-foreground">
              {{ pillar.title }}
            </h3>
            <p class="mt-2 text-sm leading-6 text-pretty text-muted-foreground">
              {{ pillar.text }}
            </p>
          </article>
        </div>
      </AuroraScene>

      <section class="relative isolate overflow-hidden rounded-2xl border border-border bg-surface p-8 md:p-10">
        <ThemedBackground
          :dark="panelGamesDark"
          :light="panelGamesLight"
        />
        <div
          aria-hidden="true"
          class="absolute inset-0 -z-10 bg-linear-to-r from-background/85 via-background/70 to-background/50"
        />
        <p class="eyebrow">
          Games
        </p>
        <h2 class="mt-3 font-display text-2xl font-semibold tracking-tight text-foreground">
          Built alongside real games
        </h2>
        <p class="mt-4 max-w-2xl text-sm leading-7 text-pretty text-muted-foreground">
          Lucy is tested on real production screens, not toy demos. <strong class="font-semibold text-foreground">Dance Lab</strong> runs its entire UI on Lucy: live HUDs, shops, audio settings, pause menus, leaderboards, and guided tours.
        </p>
        <div class="mt-6 grid gap-4 sm:grid-cols-2">
          <div class="rounded-xl border border-border bg-background/80 p-5 backdrop-blur-md">
            <h3 class="font-display text-base font-semibold text-foreground">
              Turf Heist
            </h3>
            <p class="mt-1.5 text-sm leading-6 text-muted-foreground">
              Our earlier Roblox action game that showed us what menus, HUD layouts, and controller support needed.
            </p>
          </div>
          <div class="rounded-xl border border-border bg-background/80 p-5 backdrop-blur-md">
            <div class="flex items-center justify-between gap-2">
              <h3 class="font-display text-base font-semibold text-foreground">
                Dance Lab
              </h3>
              <span class="rounded-full border border-primary/30 bg-primary/10 px-2.5 py-0.5 font-mono text-[11px] text-primary">
                Case study soon
              </span>
            </div>
            <p class="mt-1.5 text-sm leading-6 text-muted-foreground">
              In development with its entire client UI powered by Lucy. A full case study will be published when the game launches.
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
