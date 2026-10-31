/**
 * The tools: `Lucy.Devtools` (ADR 0028) as typed MCP tools, run in Studio
 * through Studio's own MCP server.
 */
import type { DataModel, DevtoolsRequest } from './luau.ts'
import { devtoolsCall, parseReply } from './luau.ts'
import type { TreeNode } from './outline.ts'
import { outline } from './outline.ts'
import type { Studio, StudioInfo } from './studio.ts'

export type Content =
  | { type: 'text', text: string }
  | { type: 'image', data: string, mimeType: string }

export interface ToolResult {
  content: Content[]
  isError?: boolean
}

export interface Tool {
  name: string
  description: string
  inputSchema: { type: 'object', properties: Record<string, unknown>, required?: string[] }
  run: (args: Record<string, unknown>) => Promise<ToolResult>
}

/** Seconds to wait after acting before a screenshot: styles land a few frames late, tweens take time. */
const SETTLE = 0.4

const STUDIO = {
  studio: {
    type: 'string',
    description: 'Which Studio: its id, or part of its place name, from `studios`. Needed only when several are open.',
  },
}
const APP = {
  app: {
    type: 'string',
    description: 'Which app, by its namePrefix, from `apps`. Needed only when several run and none was made with setCurrent.',
  },
}
const SCREENSHOT = {
  screenshot: { type: 'boolean', description: 'Also return a picture of the Studio viewport, taken after it acts.' },
}
const WHERE = 'The game\'s UI is reachable while it runs in Play (start it with Studio\'s start_stop_play);'
  + ' in edit mode, only a story shown with `preview` is.'

const text = (value: string): Content => ({ type: 'text', text: value })
const json = (value: unknown) => JSON.stringify(value, null, 2)

/** The arguments in `keys` that were given, to send on to Devtools. */
function given(args: Record<string, unknown>, keys: string[]): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const key of keys) if (args[key] !== undefined) out[key] = args[key]
  return out
}

const named = (list: StudioInfo[]) => list.map((s) => `"${s.name}" (${s.id})`).join(', ')

/** The Studio a call is for: the one open, or the one `wanted` names by id or part of its name. */
async function pickStudio(studio: Studio, wanted: unknown): Promise<StudioInfo> {
  const all = await studio.list()
  if (all.length === 0) {
    throw new Error('No Studio is connected. Open the game in Roblox Studio, with Studio\'s MCP server on.')
  }
  if (typeof wanted === 'string' && wanted !== '') {
    const exact = all.find((s) => s.id === wanted)
    if (exact) return exact
    const matches = all.filter((s) => s.name.toLowerCase().includes(wanted.toLowerCase()))
    if (matches.length === 1) return matches[0]!
    if (matches.length === 0) throw new Error(`No open Studio matches "${wanted}". Open: ${named(all)}.`)
    throw new Error(`"${wanted}" matches several Studios: ${named(matches)}. Pass an id.`)
  }
  if (all.length === 1) return all[0]!
  throw new Error(`Several Studios are open: ${named(all)}. Pass \`studio\`: an id, or part of a name.`)
}

interface CallOptions {
  /** Where to run; by default the client in Play, else edit mode. */
  dataModel?: DataModel
  screenshot?: boolean
  /** How to show the result; JSON by default. */
  show?: (result: unknown) => string
}

/** Runs one Devtools call in Studio and turns its answer into a tool result. */
async function devtools(studio: Studio, args: Record<string, unknown>, request: DevtoolsRequest, options: CallOptions = {}): Promise<ToolResult> {
  const target = await pickStudio(studio, args['studio'])
  const dataModel = options.dataModel ?? ((await studio.dataModels(target.id)).includes('Client') ? 'Client' : 'Edit')
  const code = devtoolsCall(request, dataModel, options.screenshot ? { settle: SETTLE } : {})
  const result = parseReply(await studio.run(target.id, dataModel, code))
  const refused = typeof result === 'object' && result !== null && (result as { ok?: unknown }).ok === false
  const reason = refused ? (result as { reason?: unknown }).reason : undefined
  const shown = typeof reason === 'string' ? reason : (options.show ?? json)(result)
  const content: Content[] = [text(shown)]
  if (options.screenshot) content.push(...(await picture(studio, target.id)))
  return refused ? { content, isError: true } : { content }
}

async function picture(studio: Studio, id: string): Promise<Content[]> {
  try {
    const image = await studio.capture(id)
    return [{ type: 'image', data: image.data, mimeType: image.mimeType }]
  }
  catch (error) {
    return [text(`(no screenshot: ${(error as Error).message})`)]
  }
}

/** Every error a tool meets becomes its result, so the agent reads why. */
function guarded(run: Tool['run']): Tool['run'] {
  return async (args) => {
    try {
      return await run(args ?? {})
    }
    catch (error) {
      return { content: [text((error as Error).message)], isError: true }
    }
  }
}

export function createTools(studio: Studio): Tool[] {
  const tools: Tool[] = [
    {
      name: 'studios',
      description: 'Lists the Roblox Studios open now, with their ids and place names. Other tools take `studio` when several are open.',
      inputSchema: { type: 'object', properties: {} },
      run: async () => {
        const all = await studio.list()
        return { content: [text(all.length ? all.map((s) => `${s.id}  ${s.name}`).join('\n') : 'No Studio is connected.')] }
      },
    },
    {
      name: 'apps',
      description: `Lists the running Lucy apps: name (namePrefix), theme, density, input mode, device, scene and scene stack, whether a modal is open, and how many components each has. ${WHERE}`,
      inputSchema: { type: 'object', properties: { ...STUDIO } },
      run: (args) => devtools(studio, args, { method: 'apps' }),
    },
    {
      name: 'tree',
      description: 'The UI as a tree of Lucy components in reading order: kind, id, own text, flags (disabled, checked, selected, open, focused, focus-visible), whether shown, size and position in pixels, and state.'
        + ` Ids are what press, focus and set use. ${WHERE}`,
      inputSchema: {
        type: 'object',
        properties: {
          ...STUDIO,
          ...APP,
          root: { type: 'string', description: 'Start from this component id.' },
          shownOnly: { type: 'boolean', description: 'Leave out components that are not on screen.' },
          format: { type: 'string', enum: ['outline', 'json'], description: 'outline (default): one indented line per component. json: the full nodes.' },
        },
      },
      run: (args) => devtools(studio, args, { method: 'tree', ...given(args, ['root', 'shownOnly', 'app']) }, {
        show: (result) => (args['format'] === 'json' ? json(result) : outline((result ?? []) as TreeNode[])),
      }),
    },
    {
      name: 'state',
      description: `Reads the app's store: all of it, or one dotted path (\`player.coins\`). ${WHERE}`,
      inputSchema: { type: 'object', properties: { ...STUDIO, ...APP, path: { type: 'string', description: 'A dotted path into the store.' } } },
      run: (args) => devtools(studio, args, { method: 'state', ...given(args, ['path', 'app']) }),
    },
    {
      name: 'set',
      description: `Writes the app's store at a dotted path, as game code would; the UI updates from it. ${WHERE}`,
      inputSchema: {
        type: 'object',
        properties: { ...STUDIO, ...APP, path: { type: 'string', description: 'A dotted path into the store.' }, value: { description: 'Any JSON value.' }, ...SCREENSHOT },
        required: ['path', 'value'],
      },
      run: (args) => devtools(studio, args, { method: 'set', ...given(args, ['path', 'value', 'app']) }, { screenshot: args['screenshot'] === true }),
    },
    {
      name: 'press',
      description: 'Presses a component the way a player would, through the same code as their input: clicks it, or with `value` picks that item in a toggle group, tabs, select or radio group,'
        + ' sets a slider or number field, or opens that accordion section. A disabled component stays put and the tool says why.'
        + ` Hotkeys are not pressed this way. ${WHERE}`,
      inputSchema: {
        type: 'object',
        properties: { ...STUDIO, ...APP, id: { type: 'string', description: 'The component id, from `tree`.' }, value: { description: 'What to pick or set.' }, ...SCREENSHOT },
        required: ['id'],
      },
      run: (args) => devtools(studio, args, { method: 'press', ...given(args, ['id', 'value', 'app']) }, { screenshot: args['screenshot'] === true }),
    },
    {
      name: 'focus',
      description: 'With `id`, moves focus to that component (or the first part of it that can take focus) as a gamepad player would land on it, and shows the focus ring.'
        + ` Always returns what is focused, the components around it, the input mode and whether the player is navigating. ${WHERE}`,
      inputSchema: { type: 'object', properties: { ...STUDIO, ...APP, id: { type: 'string', description: 'The component id, from `tree`.' }, ...SCREENSHOT } },
      run: (args) => devtools(studio, args, { method: 'focus', ...given(args, ['id', 'app']) }, { screenshot: args['screenshot'] === true }),
    },
    {
      name: 'overlays',
      description: `The open dialogs, sheets and popups, oldest first, each with id, kind and whether it is modal. ${WHERE}`,
      inputSchema: { type: 'object', properties: { ...STUDIO, ...APP } },
      run: (args) => devtools(studio, args, { method: 'overlays', ...given(args, ['app']) }),
    },
    {
      name: 'actions',
      description: `The app's action sets: on or off, priority, and each action's keys. ${WHERE}`,
      inputSchema: { type: 'object', properties: { ...STUDIO, ...APP } },
      run: (args) => devtools(studio, args, { method: 'actions', ...given(args, ['app']) }),
    },
    {
      name: 'preview',
      description: 'Shows a Lucy story in Studio\'s edit mode, replacing the last one, and returns a picture of it. Its components can then be read and pressed with the other tools.'
        + ' Uses a fresh copy of Lucy, so code changes show. Without `story`, takes the shown story away: do that when done, before running specs or pressing Play.',
      inputSchema: {
        type: 'object',
        properties: {
          ...STUDIO,
          story: { type: 'string', description: 'The story\'s id or title. Leave it out to clear the preview.' },
          theme: { type: 'string', description: 'A theme name, such as light or dark.' },
          device: { type: 'string', enum: ['desktop', 'mobile', 'tablet', 'console'], description: 'Which device to preview as.' },
          density: { type: 'string', enum: ['default', 'touch', 'tv'], description: 'The theme density.' },
          screenshot: { type: 'boolean', description: 'Return a picture (default true when showing a story).' },
        },
      },
      run: (args) => devtools(studio, args, { method: 'preview', ...given(args, ['story', 'theme', 'device', 'density']) }, {
        dataModel: 'Edit',
        screenshot: args['story'] !== undefined && args['screenshot'] !== false,
      }),
    },
    {
      name: 'screenshot',
      description: 'A picture of the Studio viewport as it is now.',
      inputSchema: { type: 'object', properties: { ...STUDIO } },
      run: async (args) => {
        const target = await pickStudio(studio, args['studio'])
        const image = await studio.capture(target.id)
        return { content: [{ type: 'image', data: image.data, mimeType: image.mimeType }] }
      },
    },
  ]
  return tools.map((tool) => ({ ...tool, run: guarded(tool.run) }))
}
