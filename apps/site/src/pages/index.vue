<script setup lang="ts">
import { ref } from 'vue'
import { AuroraScene } from '@goatsoft/aurora-vue'
import { RouterLink } from 'vue-router'
import heroDark from '@/backgrounds/hero-dark.aurora'
import panelSignalDark from '@/backgrounds/panel-signal-dark.aurora'
import panelSignalLight from '@/backgrounds/panel-signal-light.aurora'
import builtDark from '@/backgrounds/built-dark.aurora'
import builtLight from '@/backgrounds/built-light.aurora'
import heroLight from '@/backgrounds/hero-light.aurora'
import terminalDark from '@/backgrounds/terminal-dark.aurora'
import terminalLight from '@/backgrounds/terminal-light.aurora'
import Quickstart from '@/content/quickstart.md'
import { SITE, useHead } from '@/head'
import ThemedBackground from '@/components/ThemedBackground.vue'
import Atom from '~icons/lucide-extended/atom-duotone'
import Blocks from '~icons/lucide-extended/blocks-duotone'
import Bot from '~icons/lucide-extended/bot-duotone'
import Boxes from '~icons/lucide-extended/boxes-duotone'
import Clapperboard from '~icons/lucide-extended/clapperboard-duotone'
import Feather from '~icons/lucide-extended/feather-duotone'
import Gamepad from '~icons/lucide-extended/gamepad-2-duotone'
import Keyboard from '~icons/lucide-extended/keyboard-duotone'
import Layers from '~icons/lucide-extended/layers-duotone'
import Orbit from '~icons/lucide-extended/orbit-duotone'
import ScanEye from '~icons/lucide-extended/scan-eye-duotone'
import Shapes from '~icons/lucide-extended/shapes-duotone'
import SwatchBook from '~icons/lucide-extended/swatch-book-duotone'

useHead({ description: SITE.description })

// The hero's background follows the pointer over the whole section.
const hero = ref<HTMLElement>()

// The feature panels' glow is a light that follows the pointer across the panel.
function movePanelLight(event: PointerEvent): void {
  const panel = event.currentTarget as HTMLElement
  const box = panel.getBoundingClientRect()
  panel.style.setProperty('--light-x', `${event.clientX - box.left}px`)
  panel.style.setProperty('--light-y', `${event.clientY - box.top}px`)
}

// The four that matter most, as cards.
const features = [
  { icon: Boxes, title: '35 components', text: 'Buttons, dialogs, selects, tables, sliders, tabs and more, ready for menus, HUDs and shops.' },
  { icon: Atom, title: 'One source of truth', text: 'All UI and app state in one store. Change a value and only the properties that read it are set again.' },
  { icon: Gamepad, title: 'Any input, any device', text: 'Mouse, keyboard, gamepad and touch, on desktop, console, tablet and phone. Controls grow for touch and TV.' },
  { icon: SwatchBook, title: 'Themes', text: 'Light and dark themes for every base colour, switched while the game runs. Hover and theme changes run no Luau.' },
] as const

// Everything else, as a short list under the cards.
const more = [
  { icon: Clapperboard, title: 'Scenes', text: 'Each screen on its own layer, so menus never take input from the screen below.' },
  { icon: Layers, title: 'Dialogs and sheets', text: 'Dialogs, sheets, selects and toasts float above the game, newest on top.' },
  { icon: Keyboard, title: 'Hotkeys', text: 'Name an action once for keyboard and gamepad, and switch it off while a menu is open.' },
  { icon: Shapes, title: 'Any icon', text: 'Any Iconify icon by name, packed into a few images by the lucy-icons build.' },
  { icon: Orbit, title: 'Springs and tweens', text: 'Animate any property by binding it to a spring or a tween.' },
  { icon: Blocks, title: 'Code or Studio', text: 'Write UI in code, or add behaviour to UI you laid out in Studio.' },
  { icon: ScanEye, title: 'Preview in Studio', text: 'See any component or scene in Studio without pressing Play.' },
  { icon: Bot, title: 'Ready for agents', text: 'Skills that teach Claude Code, Codex and Antigravity to build with Lucy.' },
  { icon: Feather, title: 'Small and tested', text: 'Strict types, no runtime dependencies and over 750 specs.' },
] as const

const install = 'Lucy = "goatsoft/lucy@0.1.0"'
</script>

<template>
  <main
    id="main-content"
    tabindex="-1"
  >
    <section
      ref="hero"
      class="relative isolate overflow-hidden px-6 pt-40 pb-24 text-center"
    >
      <ThemedBackground
        :dark="heroDark"
        :light="heroLight"
        :interaction-target="hero"
      />
      <!-- A soft pool of the page colour behind the text, so the rain never runs through it. -->
      <div class="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_48%_42%_at_50%_62%,var(--background)_35%,transparent_100%)] opacity-85" />
      <!-- The shadow follows her outline (a box shadow would draw the image's square). -->
      <div class="drop-shadow-2xl">
        <Mark
          :size="256"
          class="animate-mark-in mx-auto"
        />
      </div>
      <h1 class="animate-rise mx-auto mt-8 max-w-3xl font-display text-display font-semibold tracking-loose text-balance">
        The UI and app framework for Roblox
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

    <!-- One scene across the cards: one screen of phosphor, static, glitch and scanlines,
         seen through every card on one clock, so glitches and the rolling band cross them. -->
    <AuroraScene name="features">
      <section
        id="features"
        class="relative isolate mx-auto max-w-6xl scroll-mt-24 px-6 py-20"
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
            @pointermove="movePanelLight"
            class="group relative isolate overflow-hidden rounded-2xl border border-border bg-surface p-6 [--light-x:0px] [--light-y:0px] shadow-[inset_0_1px_0_0_color-mix(in_oklab,white_8%,transparent)] transition duration-300 hover:border-primary/50 motion-safe:hover:-translate-y-0.5"
          >
            <ThemedBackground
              :dark="panelSignalDark"
              :light="panelSignalLight"
            />
            <!-- Darkest at the bottom, behind the description, fading out toward the top. -->
            <div
              aria-hidden="true"
              class="absolute inset-0 -z-10 bg-linear-to-t from-background via-background/70 to-background/10"
            />
            <!-- A violet light under the pointer while it is over the panel. -->
            <div
              aria-hidden="true"
              class="absolute inset-0 -z-10 bg-[radial-gradient(circle_16rem_at_var(--light-x)_var(--light-y),color-mix(in_oklab,var(--primary)_22%,transparent),transparent_65%)] opacity-0 transition-opacity duration-300 group-hover:opacity-100"
            />
            <div class="grid size-11 place-items-center rounded-xl bg-linear-to-br from-primary/25 to-primary/5 text-primary ring-1 ring-primary/25 ring-inset shadow-[0_8px_24px_-12px_var(--primary)] transition-transform duration-300 motion-safe:group-hover:scale-110 motion-safe:group-hover:-rotate-6 [&_svg]:size-6">
              <component
                :is="feature.icon"
                aria-hidden="true"
              />
            </div>
            <h3 class="mt-5 font-display text-base leading-snug font-semibold text-balance text-foreground">
              {{ feature.title }}
            </h3>
            <p class="mt-2 text-sm leading-6 text-pretty text-muted-foreground">
              {{ feature.text }}
            </p>
          </article>
        </div>
        <ul class="mt-12 grid gap-x-10 gap-y-6 sm:grid-cols-2 lg:grid-cols-3">
          <li
            v-for="item in more"
            :key="item.title"
            class="flex gap-3"
          >
            <component
              :is="item.icon"
              aria-hidden="true"
              class="mt-0.5 size-5 shrink-0 text-primary"
            />
            <div>
              <h3 class="font-display text-sm font-semibold text-foreground">
                {{ item.title }}
              </h3>
              <p class="mt-1 text-sm leading-6 text-pretty text-muted-foreground">
                {{ item.text }}
              </p>
            </div>
          </li>
        </ul>
      </section>
    </AuroraScene>

    <section class="relative isolate overflow-hidden">
      <ThemedBackground
        :dark="terminalDark"
        :light="terminalLight"
      />
      <div class="mx-auto max-w-4xl px-6 py-20">
        <p class="eyebrow text-center">
          Quick start
        </p>
        <h2 class="mx-auto mt-4 max-w-2xl text-center font-display text-heading font-semibold tracking-tight text-balance">
          A settings menu
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
      </div>
    </section>

    <!-- A faint radar on the same CRT screen as the feature panels. -->
    <section class="relative isolate overflow-hidden">
      <ThemedBackground
        :dark="builtDark"
        :light="builtLight"
      />
      <!-- Darkest through the middle, behind the text, fading out to the top and bottom. -->
      <div
        aria-hidden="true"
        class="absolute inset-0 -z-10 bg-linear-to-b from-transparent via-background/70 to-transparent"
      />
      <div class="mx-auto max-w-3xl px-6 py-28 text-center">
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
      </div>
    </section>
  </main>
</template>
