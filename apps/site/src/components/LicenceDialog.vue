<script setup lang="ts">
import {
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogOverlay,
  DialogPortal,
  DialogRoot,
  DialogTitle,
  DialogTrigger,
} from 'reka-ui'
import { computed } from 'vue'
import mit from '../../../../LICENSE?raw'
import art from '../../../../LICENSE-ART.md?raw'
import { SITE } from '@/head'

/**
 * A footer link that opens one of the repo's licences in a dialog. The text comes from the
 * licence files themselves, so the site never drifts from them.
 */
const props = defineProps<{ licence: 'mit' | 'art' }>()

const escape = (text: string) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

/** Bold, inline code and links; links to repo files point at GitHub. */
function inline(text: string): string {
  return escape(text)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label: string, href: string) => {
      const url = /^[a-z]+:/.test(href) ? href : `${SITE.repo}/blob/main/${href}`
      return `<a href="${url}" target="_blank" rel="noopener">${label}</a>`
    })
}

/** The licence files use only headings, paragraphs and lists, so this is all the markdown needed. */
function render(markdown: string): string {
  const blocks = markdown.trim().split(/\n\s*\n/)
  return blocks
    .map((block) => {
      const lines = block.split('\n')
      if (lines[0]?.startsWith('# ')) return ''
      if (lines[0]?.startsWith('## ')) return `<h3>${inline(lines[0].slice(3))}</h3>`
      if (lines.every(line => line.startsWith('- ')))
        return `<ul>${lines.map(line => `<li>${inline(line.slice(2))}</li>`).join('')}</ul>`
      return `<p>${inline(lines.join(' '))}</p>`
    })
    .join('')
}

const licence = computed(() =>
  props.licence === 'mit'
    ? { label: 'MIT licence', title: 'MIT licence', file: 'LICENSE', html: render(mit.replace(/^MIT License\s*/, '')) }
    : { label: 'Artwork licence', title: 'Artwork and brand licence', file: 'LICENSE-ART.md', html: render(art) },
)
</script>

<template>
  <DialogRoot>
    <DialogTrigger class="cursor-pointer underline decoration-border underline-offset-4 hover:text-foreground">
      {{ licence.label }}
    </DialogTrigger>
    <DialogPortal>
      <DialogOverlay class="fixed inset-0 z-50 bg-background/70 backdrop-blur-sm" />
      <DialogContent class="fixed top-1/2 left-1/2 z-50 flex max-h-[85vh] w-[calc(100vw-2rem)] max-w-2xl -translate-x-1/2 -translate-y-1/2 flex-col rounded-2xl border border-border bg-surface shadow-2xl focus:outline-none">
        <div class="flex items-start justify-between gap-4 border-b border-border px-6 py-5">
          <div>
            <DialogTitle class="font-display text-lg font-semibold text-foreground">
              {{ licence.title }}
            </DialogTitle>
            <DialogDescription class="mt-1 text-xs text-muted-foreground">
              <a
                :href="`${SITE.repo}/blob/main/${licence.file}`"
                target="_blank"
                rel="noopener"
                class="underline decoration-border underline-offset-4 hover:text-foreground"
              >{{ licence.file }}</a> in the Lucy repository
            </DialogDescription>
          </div>
          <DialogClose
            class="grid size-8 shrink-0 cursor-pointer place-items-center rounded-lg text-muted-foreground transition-colors hover:bg-foreground/10 hover:text-foreground"
            aria-label="Close"
          >
            <ILcX class="size-4" />
          </DialogClose>
        </div>
        <!-- eslint-disable-next-line vue/no-v-html -- our own licence files, escaped above -->
        <div
          class="licence overflow-y-auto px-6 py-5 text-sm leading-6 text-muted-foreground"
          v-html="licence.html"
        />
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>

<style scoped>
.licence :deep(h3) { margin-top: 1.25rem; margin-bottom: 0.5rem; font-weight: 600; color: var(--foreground); }
.licence :deep(p) { margin-bottom: 0.75rem; }
.licence :deep(ul) { margin-bottom: 0.75rem; padding-left: 1.25rem; list-style: disc; }
.licence :deep(li) { margin-bottom: 0.25rem; }
.licence :deep(strong) { color: var(--foreground); font-weight: 600; }
.licence :deep(code) { font-family: var(--font-mono); font-size: 0.8em; color: var(--foreground); }
.licence :deep(a) { color: var(--primary); text-decoration: underline; text-underline-offset: 4px; }
</style>
