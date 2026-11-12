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
import Contrast from '~icons/lucide-extended/contrast-duotone'
import DatabaseZap from '~icons/lucide-extended/database-zap-duotone'
import Gamepad from '~icons/lucide-extended/gamepad-2-duotone'
import Globe from '~icons/lucide-extended/globe-duotone'
import Keyboard from '~icons/lucide-extended/keyboard-duotone'
import ScanEye from '~icons/lucide-extended/scan-eye-duotone'
import Shapes from '~icons/lucide-extended/shapes-duotone'
import Signpost from '~icons/lucide-extended/signpost-duotone'
import SwatchBook from '~icons/lucide-extended/swatch-book-duotone'

useHead({ description: SITE.description })

// The hero's background follows the pointer over the whole section.
const hero = ref<HTMLElement>()

// The quick start opens on the picture of what the code makes; Code shows the script.
const quickstartViews = [
  { id: 'preview', label: 'Preview' },
  { id: 'code', label: 'Code' },
] as const
const quickstartView = ref<'preview' | 'code'>('preview')

// The feature panels' glow is a light that follows the pointer across the panel.
function movePanelLight(event: PointerEvent): void {
  const panel = event.currentTarget as HTMLElement
  const box = panel.getBoundingClientRect()
  panel.style.setProperty('--light-x', `${event.clientX - box.left}px`)
  panel.style.setProperty('--light-y', `${event.clientY - box.top}px`)
}

// The four that matter most, as cards.
const features = [
  { icon: Boxes, title: 'Components ready to ship', text: 'Drop buttons, dialogs, tabs, and leaderboards straight into HUDs, shops, or menus.', to: '/docs/components/' },
  { icon: Atom, title: 'One store, zero glue', text: 'Update coins or settings once. Only the UI bound to them changes.', to: '/docs/guide/app-state' },
  { icon: Gamepad, title: 'PC, console, and mobile', text: 'Gamepad focus, keyboard shortcuts, and touch targets scale from phones to TVs.', to: '/docs/guide/accessibility' },
  { icon: SwatchBook, title: 'Live themes, zero script cost', text: 'Swap palettes anytime. Hovers and themes run in Roblox StyleSheets, not Luau.', to: '/docs/guide/themes' },
] as const

// High level game capabilities, as a short list under the cards.
const more = [
  { icon: Clapperboard, title: 'Scenes', text: 'Layer your Title, HUD, and menus so modals block clicks behind them.', to: '/docs/guide/scenes' },
  { icon: Keyboard, title: 'Hotkeys', text: 'Bind keyboard and gamepad actions once, then pause gameplay keys in menus.', to: '/docs/guide/actions' },
  { icon: DatabaseZap, title: 'Server and boards', text: 'Sync server state without RemoteEvents. Includes DataStore pacing and leaderboards.', to: '/docs/guide/server' },
  { icon: Globe, title: 'UI in the world', text: 'Themed, clickable SurfaceGuis and BillboardGuis driven by your game state.', to: '/docs/guide/world-ui' },
  { icon: Signpost, title: 'Guided tours', text: 'Spotlight tutorials over your real menus with zero duplicate UI.', to: '/docs/guide/tutorials' },
  { icon: Contrast, title: 'Accessibility', text: 'Verified colour contrast, plus Roblox reduce motion, text size, and transparency.', to: '/docs/guide/accessibility' },
  { icon: Shapes, title: 'Icons', text: 'Use Iconify icons by name. lucy-icons packs them into sheets for you.', to: '/docs/guide/icons' },
  { icon: Blocks, title: 'Code or Studio', text: 'Build UI in Luau, or lay it out in Studio with Lucy.hydrate.', to: '/docs/reactivity#ui-built-in-studio' },
  { icon: ScanEye, title: 'Preview in Studio', text: 'Inspect components and full screens in edit mode without pressing Play.', to: '/docs/stories' },
  { icon: Bot, title: 'Ready for agents', text: 'Agent skills and MCP server to inspect UI trees or take screenshots.', to: '/docs/guide/agents' },
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
          Why your game needs Lucy
        </h2>
        <div class="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <RouterLink
            v-for="feature in features"
            :key="feature.title"
            :to="feature.to"
            @pointermove="movePanelLight"
            class="group relative isolate block overflow-hidden rounded-2xl border border-border bg-surface p-6 [--light-x:0px] [--light-y:0px] shadow-[inset_0_1px_0_0_color-mix(in_oklab,white_8%,transparent)] transition duration-300 hover:border-primary/50 focus-visible:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/50 motion-safe:hover:-translate-y-0.5"
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
            <h3 class="mt-5 font-display text-base leading-snug font-semibold text-balance text-foreground transition-colors group-hover:text-primary">
              {{ feature.title }}
            </h3>
            <p class="mt-2 text-sm leading-6 text-pretty text-muted-foreground">
              {{ feature.text }}
            </p>
          </RouterLink>
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
                <RouterLink
                  :to="item.to"
                  class="transition-colors hover:text-primary focus-visible:text-primary focus-visible:outline-none"
                >
                  {{ item.title }}
                </RouterLink>
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
          A working settings menu in one script
        </h2>
        <p class="mx-auto mt-4 max-w-xl text-center text-base leading-7 text-pretty text-muted-foreground">
          Bind sliders and dropdowns straight to game state. Switch the theme and the whole UI updates at once.
        </p>
        <div class="mt-10 flex justify-center">
          <div
            role="tablist"
            aria-label="Quick start"
            class="glass inline-flex gap-1 rounded-full p-1"
          >
            <button
              v-for="view in quickstartViews"
              :key="view.id"
              role="tab"
              type="button"
              :aria-selected="quickstartView === view.id"
              class="inline-flex h-9 items-center gap-2 rounded-full px-4 text-sm font-semibold transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring [&_svg]:size-4"
              :class="quickstartView === view.id ? 'bg-foreground text-background' : 'text-muted-foreground hover:text-foreground'"
              @click="quickstartView = view.id"
            >
              <ILxEyeFilled v-if="view.id === 'preview'" />
              <ILxFileCodeFilled v-else />
              {{ view.label }}
            </button>
          </div>
        </div>
        <div
          class="prose quickstart mt-6"
          :data-view="quickstartView"
        >
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
          How it works
        </p>
        <h2 class="mx-auto mt-4 max-w-2xl font-display text-heading font-semibold tracking-tight text-balance">
          Fast UI without the script spaghetti
        </h2>
        <p class="mx-auto mt-6 max-w-2xl text-lg leading-8 text-pretty text-muted-foreground">
          Roblox UI usually breaks in two ways: scattered scripts fighting over ScreenGuis, or heavy UI trees rebuilding every time a stat changes.
          Lucy puts one App in charge of your screens, input, and state. Instances build once, only the changed property updates, and Roblox StyleSheets handle all looks, keeping even busy HUDs fast.
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
