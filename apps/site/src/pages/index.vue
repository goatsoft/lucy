<script setup lang="ts">
import { RouterLink } from 'vue-router'
import Quickstart from '@/content/quickstart.md'
import { SITE, useHead } from '@/head'

useHead({ description: SITE.description })

const features = [
  { icon: 'fast', title: 'Fine-grained by design', text: 'Change a value and only the properties that read it update. Nothing re-renders and nothing is diffed, so long lists and busy HUDs stay cheap.' },
  { icon: 'code', title: 'State that reads like Luau', text: 'Refs you call like functions, cached computed values, reactive tables you write as fields, and watchers. No dependency lists, no boilerplate.' },
  { icon: 'clean', title: 'Cleans up after itself', text: 'Effects, bindings and instances belong to whatever created them and go away with it. No cleanup bookkeeping, no leaks.' },
  { icon: 'declarative', title: 'Declarative, or built in Studio', text: 'Describe UI with Lucy.new, show and each, or hydrate a ScreenGui built in Studio and just add the behaviour.' },
  { icon: 'motion', title: 'Motion is a value', text: 'Springs and tweens bind like any other state. Colours glide through Oklab, and nothing runs while everything is at rest.' },
  { icon: 'components', title: 'Components you own', text: 'Buttons, dialogs, toasts, inputs, panels and more. Copy them into your game with one command, or install the Wally package.' },
  { icon: 'themes', title: 'Styling runs in the engine', text: 'Themes are Universal Styling sheets: light and dark per base colour, switched at runtime, with hover and theme changes costing no Lua.' },
  { icon: 'input', title: 'Every input', text: 'Mouse, keyboard, gamepad and touch, with Tab and arrow navigation, focus that stays inside dialogs and back on Escape or B.' },
  { icon: 'focus', title: 'Lucy owns focus', text: 'No default selection rings or borders. A themed focus ring shows only while navigating with keys or a gamepad.' },
  { icon: 'devices', title: 'Every screen', text: 'Desktop, console, tablet and phone. Adaptive scaling, 44px touch targets, 10-foot sizes and responsive props.' },
  { icon: 'scenes', title: 'One app, clean scenes', text: 'One store drives every component, scene and toast. Title screen, game, menus and modals each own a layer and never steal input.' },
  { icon: 'light', title: 'Light and dependable', text: 'One package with no runtime dependencies, strict types throughout, and hundreds of specs run in Studio.' },
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
      <h1 class="animate-rise mx-auto mt-8 max-w-3xl font-display text-display font-semibold tracking-tight text-balance">
        A UI kit for <span class="text-spectrum">Roblox</span>
      </h1>
      <p class="animate-rise mx-auto mt-6 max-w-2xl text-lead text-pretty text-muted-foreground [animation-delay:120ms]">
        Fine-grained reactive state, declarative UI and themeable components, with first-class mouse,
        keyboard, gamepad and touch on desktop, console, tablet and phone.
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
      <h2 class="mx-auto mt-4 max-w-2xl text-center font-display text-heading font-semibold tracking-tight text-balance">
        Everything a game UI needs, out of the box
      </h2>
      <div class="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <article
          v-for="feature in features"
          :key="feature.title"
          class="rounded-2xl border border-border bg-surface/60 p-6"
        >
          <div class="grid size-10 place-items-center rounded-xl bg-primary/15 text-primary [&_svg]:size-5">
            <IHgFlash v-if="feature.icon === 'fast'" />
            <IHgCode v-else-if="feature.icon === 'code'" />
            <IHgSparkles v-else-if="feature.icon === 'clean'" />
            <IHgStructure03 v-else-if="feature.icon === 'declarative'" />
            <IHgWave v-else-if="feature.icon === 'motion'" />
            <IHgPackage v-else-if="feature.icon === 'components'" />
            <IHgPaintBoard v-else-if="feature.icon === 'themes'" />
            <IHgGameController03 v-else-if="feature.icon === 'input'" />
            <IHgFocusPoint v-else-if="feature.icon === 'focus'" />
            <IHgComputerPhoneSync v-else-if="feature.icon === 'devices'" />
            <IHgFeather v-else-if="feature.icon === 'light'" />
            <IHgLayers01 v-else />
          </div>
          <h3 class="mt-5 font-display text-lg font-semibold text-foreground">
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
      <h2 class="mx-auto mt-4 max-w-2xl text-center font-display text-heading font-semibold tracking-tight text-balance">
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
