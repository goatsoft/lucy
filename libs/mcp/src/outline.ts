/** A component as `Devtools.tree` gives it. */
export interface TreeNode {
  id?: string
  kind?: string
  text?: string
  flags?: string[]
  shown?: boolean
  size?: number[]
  position?: number[]
  /** Its state; Studio sends an empty table as `[]`. */
  state?: Record<string, unknown> | unknown[]
  /** `false` when its content is built on first show and has not been yet. */
  built?: boolean
  /** The parts of it not built yet (a Tabs' tab values). */
  unbuilt?: unknown[]
  children?: TreeNode[]
}

/**
 * The tree as an outline, one line per component, children indented:
 *
 *     panel #shop 400x300 at 10,20
 *       button #buy "Buy" [focused] 120x40 at 20,240
 *       tabs #sections 380x200 at 20,30 unbuilt: "moves" "drinks"
 */
export function outline(tree: TreeNode[]): string {
  const lines: string[] = []
  const walk = (nodes: TreeNode[], depth: number) => {
    for (const node of nodes) {
      lines.push('  '.repeat(depth) + line(node))
      walk(node.children ?? [], depth + 1)
    }
  }
  walk(tree, 0)
  return lines.length ? lines.join('\n') : '(no components)'
}

function line(node: TreeNode): string {
  const parts = [`${node.kind ?? 'component'} #${node.id ?? '?'}`]
  if (node.text) parts.push(JSON.stringify(node.text))
  if (node.flags?.length) parts.push(`[${node.flags.join(', ')}]`)
  if (node.shown === false) parts.push('(hidden)')
  if (node.built === false) parts.push('(not built)')
  if (node.size) parts.push(`${node.size[0]}x${node.size[1]}`)
  if (node.position) parts.push(`at ${node.position[0]},${node.position[1]}`)
  const state = node.state && !Array.isArray(node.state) ? Object.entries(node.state) : []
  if (state.length) parts.push(`state: ${state.map(([k, v]) => `${k}=${JSON.stringify(v)}`).join(' ')}`)
  if (node.unbuilt?.length) parts.push(`unbuilt: ${node.unbuilt.map((v) => JSON.stringify(v)).join(' ')}`)
  return parts.join(' ')
}
