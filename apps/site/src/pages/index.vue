<script setup lang="ts">
import { RouterLink } from 'vue-router'
import Quickstart from '@/content/quickstart.md'
import { SITE, useHead } from '@/head'

useHead({ description: SITE.description })

const features = [
  { icon: 'components', title: 'Components you own', text: 'Copy components into your game with one command, or install the Wally package. Buttons, dialogs, toasts, inputs, panels and more.' },
  { icon: 'themes', title: 'Themes as data', text: 'Light and dark themes per base colour with an optional primary hue, built on Universal Styling and switched at runtime.' },
  { icon: 'input', title: 'Every input', text: 'Mouse, keyboard, gamepad and touch, with Tab and arrow navigation, focus that stays inside dialogs and back on Escape or B.' },
  { icon: 'devices', title: 'Every screen', text: 'Desktop, console, tablet and phone. Adaptive scaling, 44px touch targets, 10-foot sizes and responsive props.' },
  { icon: 'state', title: 'One app state', text: 'Every component, scene and toast reads from one store. Set ui.play.disabled from anywhere and the button follows.' },
  { icon: 'scenes', title: 'Scenes that never clash', text: 'Title screen, game, menus and modals each own a layer, so screens never overlap or steal each other’s input.' },
] as const

const install = 'lune run ~/Projects/Lucy/scripts/add -- button dialog --out src/shared/Lucy'
</script>

<template>
  <main
    id="main-content"
    tabindex="-1"
  >
    <section class="relative isolate overflow-hidden px-6 pt-40 pb-24 text-center">
      <div class="absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_top,color-mix(in_oklab,var(--primary)_28%,transparent),transparent_60%)]" />
      <Mark
        :size="72"
        class="animate-mark-in mx-auto"
      />
      <h1 class="animate-rise mx-auto mt-8 max-w-3xl text-display font-semibold tracking-tight text-balance">
        A UI kit for <span class="text-spectrum">Roblox</span>
      </h1>
      <p class="animate-rise mx-auto mt-6 max-w-2xl text-lead text-pretty text-muted-foreground [animation-delay:120ms]">
        Themeable components, scenes and app state, with first-class mouse, keyboard, gamepad and
        touch on desktop, console, tablet and phone.
      </p>
      <div class="animate-rise mt-10 flex flex-col justify-center gap-3 sm:flex-row [animation-delay:200ms]">
        <Button
          size="lg"
          :as="RouterLink"
          to="/docs"
        >
          Get started <IHgArrowRight01 />
        </Button>
        <Button
          size="lg"
          variant="glass"
          as="a"
          :href="SITE.repo"
          target="_blank"
          rel="noopener"
        >
          <ISiGithub /> GitHub
        </Button>
      </div>
      <p class="mx-auto mt-8 max-w-full overflow-x-auto font-mono text-xs text-muted-foreground">
        <span class="text-primary">$</span> {{ install }}
      </p>
    </section>

    <section
      id="features"
      class="mx-auto max-w-6xl scroll-mt-24 px-6 py-20"
    >
      <p class="eyebrow text-center">
        Features
      </p>
      <h2 class="mx-auto mt-4 max-w-2xl text-center text-heading font-semibold tracking-tight text-balance">
        Everything a game UI needs, out of the box
      </h2>
      <div class="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <article
          v-for="feature in features"
          :key="feature.title"
          class="rounded-2xl border border-border bg-surface/60 p-6"
        >
          <div class="grid size-10 place-items-center rounded-xl bg-primary/15 text-primary [&_svg]:size-5">
            <IHgPackage v-if="feature.icon === 'components'" />
            <IHgPaintBoard v-else-if="feature.icon === 'themes'" />
            <IHgGameController03 v-else-if="feature.icon === 'input'" />
            <IHgComputerPhoneSync v-else-if="feature.icon === 'devices'" />
            <IHgDatabase01 v-else-if="feature.icon === 'state'" />
            <IHgLayers01 v-else />
          </div>
          <h3 class="mt-5 font-semibold text-foreground">
            {{ feature.title }}
          </h3>
          <p class="mt-2 text-sm leading-6 text-muted-foreground">
            {{ feature.text }}
          </p>
        </article>
      </div>
    </section>

    <section class="mx-auto max-w-4xl px-6 py-20">
      <p class="eyebrow text-center">
        Quick start
      </p>
      <h2 class="mx-auto mt-4 max-w-2xl text-center text-heading font-semibold tracking-tight text-balance">
        A title screen in a dozen lines
      </h2>
      <div class="prose mt-10">
        <Quickstart />
      </div>
      <div class="mt-8 flex justify-center">
        <Button
          variant="glass"
          :as="RouterLink"
          to="/docs"
        >
          <IHgBook02 /> Read the docs
        </Button>
      </div>
    </section>
  </main>
</template>
