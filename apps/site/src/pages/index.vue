<script setup lang="ts">
import { RouterLink } from 'vue-router'
import Quickstart from '@/content/quickstart.md'
import { SITE, useHead } from '@/head'
import Atom from '~icons/lucide-extended/atom-duotone'
import Blocks from '~icons/lucide-extended/blocks-duotone'
import Boxes from '~icons/lucide-extended/boxes-duotone'
import BrushCleaning from '~icons/lucide-extended/brush-cleaning-duotone'
import Clapperboard from '~icons/lucide-extended/clapperboard-duotone'
import Feather from '~icons/lucide-extended/feather-duotone'
import Gamepad from '~icons/lucide-extended/gamepad-2-duotone'
import MonitorSmartphone from '~icons/lucide-extended/monitor-smartphone-duotone'
import Orbit from '~icons/lucide-extended/orbit-duotone'
import ScanEye from '~icons/lucide-extended/scan-eye-duotone'
import SquareCode from '~icons/lucide-extended/square-code-duotone'
import SwatchBook from '~icons/lucide-extended/swatch-book-duotone'

useHead({ description: SITE.description })

const features = [
  { icon: Boxes, title: '28 components', text: 'Button, Dialog, Toaster, Input, Checkbox, Switch, Panel, Progress and more.' },
  { icon: Atom, title: 'Small updates', text: 'When a value changes, only the properties that read it are set again. Nothing is rebuilt.' },
  { icon: SquareCode, title: 'State in plain Luau', text: 'Refs, computed values and reactive tables. Any property can follow any of them.' },
  { icon: Blocks, title: 'Code or Studio', text: 'Write UI in code with Lucy.new, or add behaviour to UI you laid out in Studio.' },
  { icon: SwatchBook, title: 'Light and dark themes', text: 'A theme for each base colour, switched while the game runs. Hover and theme changes run no Luau.' },
  { icon: Gamepad, title: 'Every input', text: 'Mouse, keyboard, gamepad and touch. The focus ring shows only for keys and gamepads.' },
  { icon: MonitorSmartphone, title: 'Every device', text: 'Desktop, console, tablet and phone. Controls grow for touch and for TV screens.' },
  { icon: Clapperboard, title: 'Scenes', text: 'Each screen is a scene on its own layer, so menus never take input from the screen below.' },
  { icon: Orbit, title: 'Springs and tweens', text: 'Animate any property by binding it to a spring or a tween.' },
  { icon: ScanEye, title: 'Preview in Studio', text: 'Stories show any component or scene in Studio without pressing Play.' },
  { icon: BrushCleaning, title: 'Cleans up', text: 'Bindings and instances are removed along with whatever created them.' },
  { icon: Feather, title: 'Small and tested', text: 'Strict types, no runtime dependencies and over 350 specs.' },
] as const

const install = 'Lucy = "goatsoft/lucy@0.1.0"'
</script>

<template>
  <main
    id="main-content"
    tabindex="-1"
  >
    <section class="relative isolate overflow-hidden px-6 pt-40 pb-24 text-center">
      <div class="absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_top,color-mix(in_oklab,var(--primary)_28%,transparent),transparent_60%)]" />
      <Mark
        :size="256"
        class="animate-mark-in mx-auto shadow-2xl"
      />
      <h1 class="animate-rise mx-auto mt-8 max-w-3xl font-display text-display font-semibold tracking-loose text-balance">
        A UI kit and app framework for Roblox
      </h1>
      <p class="animate-rise mx-auto mt-6 max-w-2xl text-lead text-pretty tracking-tight leading-8 text-muted-foreground [animation-delay:120ms]">
        {{ SITE.description }}
      </p>
      <div class="animate-rise mt-10 flex flex-col justify-center gap-3 sm:flex-row [animation-delay:200ms]">
        <Button
          size="lg"
          :as="RouterLink"
          to="/docs/"
        >
          Get started <ILcChevronRight />
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
        <span class="text-primary">wally.toml</span> {{ install }}
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
        What Lucy does
      </h2>
      <div class="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <article
          v-for="feature in features"
          :key="feature.title"
          class="group relative isolate overflow-hidden rounded-2xl border border-border bg-surface/60 p-5 transition duration-300 hover:border-primary/40 motion-safe:hover:-translate-y-0.5"
        >
          <div
            aria-hidden="true"
            class="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_0%_0%,color-mix(in_oklab,var(--primary)_16%,transparent),transparent_65%)] opacity-0 transition-opacity duration-300 group-hover:opacity-100"
          />
          <div class="flex items-center gap-3">
            <div class="grid size-11 shrink-0 place-items-center rounded-xl bg-linear-to-br from-primary/25 to-primary/5 text-primary ring-1 ring-primary/25 ring-inset shadow-[0_8px_24px_-12px_var(--primary)] transition-transform duration-300 motion-safe:group-hover:scale-110 motion-safe:group-hover:-rotate-6 [&_svg]:size-6">
              <component
                :is="feature.icon"
                aria-hidden="true"
              />
            </div>
            <h3 class="font-display text-base leading-snug font-semibold text-balance text-foreground">
              {{ feature.title }}
            </h3>
          </div>
          <p class="mt-3 text-sm leading-6 text-pretty text-muted-foreground">
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
        A title screen and a game screen
      </h2>
      <div class="prose mt-10">
        <Quickstart />
      </div>
      <div class="mt-8 flex justify-center">
        <Button
          variant="glass"
          :as="RouterLink"
          to="/docs/"
        >
          <ILxBookOpenDuotone /> Read the docs
        </Button>
      </div>
    </section>

    <section class="mx-auto max-w-3xl px-6 py-20 text-center">
      <p class="eyebrow">
        Architecture
      </p>
      <h2 class="mx-auto mt-4 max-w-2xl font-display text-heading font-semibold tracking-tight text-balance">
        How it is built
      </h2>
      <p class="mx-auto mt-6 max-w-2xl text-lg leading-8 text-pretty text-muted-foreground">
        Each client has one App. It holds the UI state in a single tree, the theme, input and focus, the scenes and the toasts.
        Every component keeps its state in that tree, builds its instances once and binds their properties to the state.
        Looks come from Universal Styling rules matched by tags.
      </p>
      <div class="mt-8 flex justify-center">
        <Button
          variant="glass"
          :as="RouterLink"
          to="/docs/architecture"
        >
          Architecture guide <ILcChevronRight />
        </Button>
      </div>
    </section>
  </main>
</template>
