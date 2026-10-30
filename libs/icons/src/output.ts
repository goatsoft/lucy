import type { Layout } from './layout.ts'
import { slot } from './layout.ts'
import type { SetInfo } from './sets.ts'

export interface Entry {
  name: string
  /** slot number in the lock's order */
  index: number
  tint: boolean
}

/**
 * The generated Luau module: name -> { image, rect, tint }, the map
 * Lucy.Icon.register takes. `sheetIds[i]` is sheet i's asset id.
 */
export function luauModule(entries: Entry[], sheetIds: string[], layout: Layout, sets: SetInfo[]): string {
  const lines: string[] = []
  lines.push('--!strict')
  lines.push('-- Made by lucy-icons from lucy-icons.json. Do not edit: run `lucy-icons build`.')
  lines.push('-- Register once, before building UI: Lucy.Icon.register(require(path.to.this))')
  if (sets.length > 0) {
    lines.push('--')
    lines.push('-- Icon sets and their licences:')
    for (const set of [...sets].sort((a, b) => a.prefix.localeCompare(b.prefix))) {
      const note = set.attribution ? ' (needs attribution)' : ''
      const url = set.licenceUrl ? ` ${set.licenceUrl}` : ''
      lines.push(`--   ${set.prefix}: ${set.name}, ${set.licence}${note}${url}`)
    }
  }
  lines.push('')
  const used = [...new Set(entries.map(e => slot(e.index, layout).sheet))].sort((a, b) => a - b)
  for (const sheet of used) {
    lines.push(`local sheet${sheet + 1} = "rbxassetid://${sheetIds[sheet]}"`)
  }
  lines.push('')
  lines.push('return {')
  for (const entry of [...entries].sort((a, b) => a.name.localeCompare(b.name))) {
    const at = slot(entry.index, layout)
    const tint = entry.tint ? '' : ', tint = false'
    lines.push(
      `\t["${entry.name}"] = { image = sheet${at.sheet + 1}, rect = { ${at.x}, ${at.y}, ${layout.size}, ${layout.size} }${tint} },`,
    )
  }
  lines.push('}')
  return lines.join('\n') + '\n'
}
