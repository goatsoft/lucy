import type { MarkdownIt } from 'markdown-it'
import type { BundledLanguage, BundledTheme } from 'shiki'
import { transformerNotationDiff, transformerNotationFocus, transformerNotationHighlight } from '@shikijs/transformers'
import { createHighlighter } from 'shiki'

export interface HighlightOptions {
  themes?: { light: BundledTheme, dark: BundledTheme }
  langs?: BundledLanguage[]
}

const DEFAULT_LANGS: BundledLanguage[] = ['luau', 'lua', 'toml', 'ts', 'js', 'vue', 'html', 'css', 'json', 'jsonc', 'sh', 'md', 'yaml', 'diff']

/** `ts [vite.config.ts]` → the language and an optional title. */
export function parseInfo(info: string): { lang: string, title: string | undefined } {
  const lang = info.trim().split(/[\s{[]/, 1)[0] ?? ''
  const title = /\[([^\]]+)\]/.exec(info)?.[1]
  return { lang, title }
}

/**
 * Code blocks highlighted at build time by Shiki, in light and dark themes at once (switched by
 * CSS), with `// [!code highlight]`, `// [!code ++]` / `// [!code --]` and `// [!code focus]`
 * notation. A `[title]` after the language names the file (and the tab in a code-group).
 */
export async function createCodeHighlighter(options: HighlightOptions = {}) {
  const themes = options.themes ?? { light: 'github-light', dark: 'github-dark-dimmed' }
  const langs = options.langs ?? DEFAULT_LANGS
  const shiki = await createHighlighter({ themes: [themes.light, themes.dark], langs })
  const known = new Set(shiki.getLoadedLanguages())
  const transformers = [transformerNotationHighlight(), transformerNotationDiff(), transformerNotationFocus()]
  const code = (source: string, lang: string) => shiki.codeToHtml(source, {
    lang: known.has(lang) ? lang : 'text',
    themes,
    defaultColor: false,
    transformers,
  })

  return code
}

export async function highlight(md: MarkdownIt, options: HighlightOptions = {}): Promise<void> {
  const code = await createCodeHighlighter(options)
  md.renderer.rules['fence'] = (tokens, idx) => {
    const token = tokens[idx]!
    const { lang, title } = parseInfo(token.info)
    const source = token.content
    const head = title ? `<div class="code-title">${md.utils.escapeHtml(title)}</div>` : ''
    return `<div class="code-block" data-lang="${md.utils.escapeHtml(lang)}"${title ? ` data-title="${md.utils.escapeHtml(title)}"` : ''}>${head}${code(source, lang)}<CopyButton code="${md.utils.escapeHtml(source)}" /></div>\n`
  }
}
