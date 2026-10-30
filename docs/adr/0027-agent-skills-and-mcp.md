# 0027: Agent skills, a debugging module and an MCP server

- Status: proposed (JB accepted the shape 2026-10-31; names and layout below await his read)
- Date: 2026-10-31

## Context

People build Roblox games with coding agents (Claude Code, Codex, Antigravity
and others). An agent that does not know Lucy writes plain Roblox UI, misses
the component it needed, or guesses at props. Lucy's docs are good but an
agent has to be told to read them.

Roblox Studio has its own MCP server, built into Studio. Agents use it to read
and edit the place, run Luau (`execute_luau`), play test and take screenshots.
Its "autodiscovery" is quick connect: Studio writes its own entry into each
supported client's MCP config. Third parties cannot add tools to it.

Studio's Assistant has skills too, but custom skills belong to the creator's
Roblox account and show up in every place. Roblox has said skills that live in
a place, and reach agents through Studio's MCP server, are on its roadmap.

Measured (2026-10-31): another program can talk to Studio's MCP server. A Node
script spawned `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`, did
the MCP handshake (server "RobloxStudio", protocol 2025-06-18), listed its 34
tools and both open Studios, and ran `execute_luau` in LucyTests.

How the three agents load things (October 2026):

| | Skills (project) | MCP (project) | Plugins |
|---|---|---|---|
| Claude Code | `.claude/skills/<name>/SKILL.md` | `.mcp.json` | `.claude-plugin/marketplace.json` in a GitHub repo |
| Codex | `.agents/skills/<name>/SKILL.md` | `.codex/config.toml` `[mcp_servers.<name>]` | `.agents/plugins/marketplace.json` in a GitHub repo |
| Antigravity | `.agents/skills/<name>/SKILL.md` | `.agents/mcp_config.json` | none |

All three read the same SKILL.md format (frontmatter `name` and `description`,
then markdown, with optional files beside it).

## Decision

The MCP server is for agents **building with Lucy**. Agents keep using Studio's
own MCP server to work in Studio.

### 1. Skills, in the repo, generated from the docs

`plugins/lucy/skills/`:

- **`lucy`**: building UI with Lucy. A short SKILL.md (app setup, how
  components, state, styling and actions fit together, the rules agents get
  wrong) plus `references/`: one file per component and one per guide topic.
- **`lucy-icons`**: adding icons, the config, building and uploading.
- **`lucy-debug`**: looking at a running Lucy UI in Studio with the debugging
  module (2) through Studio's `execute_luau` and `screen_capture`.

The docs stay the one home for each topic. `references/` is generated from
`docs/` by `scripts/skills.ts` (site only parts removed, links rewritten), and
CI runs it with `--check` so the skills never drift. Only the SKILL.md files
are written by hand.

Each skill is checked by running real tasks with an agent before it ships
(a task list kept in the repo, run by hand for now).

### 2. A debugging module in the Lucy package

`Lucy.Devtools`, in the Wally package, required only when called, Studio and
client only. Plain functions that return plain tables, for agents to call with
`execute_luau`:

- `apps()`: the running apps.
- `tree(app?, options?)`: the UI as a tree of components with their kind,
  props, state tags and size, not raw instances.
- `focus(app?)`, `overlays(app?)`, `actions(app?)`: what is focused and the
  input mode, the overlay stack, and actions with their keys and sets.
- `state(app?, path?)`: the store.
- `preview(story, options?)`: shows a story, for a screenshot.

It reads what Lucy already tracks; it changes nothing except `preview`.

### 3. An MCP server: `@goatsoft/lucy-mcp`, in `libs/mcp`

A Node stdio server, published to npm like lucy-icons. Tools:

- **Docs:** search and read Lucy's docs and component reference, bundled in
  the package, so it works offline.
- **Icons:** run the lucy-icons build and check (as a library).
- **Studio, through Studio's MCP server:** it spawns Studio's MCP binary as a
  client (path per OS, as Studio's docs give it) and calls `execute_luau` with
  the debugging module, so agents get `ui_tree`, `preview_story` (with a
  screenshot) and the like without writing Luau. Every tool takes Studio's
  `studio_id`. If Studio's server is off, the tool says how to turn it on.

It never ships its own Studio plugin.

### 4. Getting it into a game

- **Claude Code and Codex plugins**, listed from the GitHub repo:
  `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` at
  the repo root point at `plugins/lucy/`, which holds both manifests
  (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`), the skills and
  a `.mcp.json` that runs `npx -y @goatsoft/lucy-mcp`.
- **`npx @goatsoft/lucy-mcp setup`** does what Studio's quick connect does, for
  a game's repo: copies the skills into `.agents/skills/` with `.claude/skills/`
  links to them, and adds the server to `.mcp.json`, `.codex/config.toml` and
  `.agents/mcp_config.json`, merging with what is there. Antigravity gets
  everything this way.
- **A docs page, "Use Lucy with agents"** (`docs/guide/agents.md`): installing
  for Claude Code, Codex and Antigravity. Other agents read the same files and
  can be set up from it by hand. The docs name these agents (an exception to
  "don't name other libraries", like Iconify), and Roblox Studio's MCP server.
- **Studio's Assistant:** nothing for now. When Roblox ships skills that live
  in a place, Lucy's package carries its skills there, and agents find them
  through Studio's MCP server with no setup.

### Order

Skills, the generator and the docs page, then `Lucy.Devtools`, then the Dance
Lab rebuild. The MCP server follows when the rebuild shows what it needs.

## Consequences

- An agent with the plugin, or a repo after `setup`, knows Lucy without being
  told to read the docs.
- Skills cannot fall behind the docs: CI fails until they are regenerated.
- `Lucy.Devtools` adds a module to the package. It loads only when used.
- The MCP server's Studio tools depend on Studio's MCP binary and its tool
  names (`execute_luau`, `screen_capture`), which Roblox may change. They are
  kept in one file.
- Two plugin manifests and three MCP config formats to keep in step; `setup`
  and CI hold them in one place.

## Alternatives considered

- **Hand written skills.** They drift from the docs.
- **The MCP server with its own Studio plugin**, like Roblox's older
  standalone server. Duplicates Studio's built in server and needs installing.
- **Skills in each creator's Roblox account** through Studio's `create_skill`.
  They would show in every place, not just Lucy games, and edits there would
  not come back to the repo. Place skills replace this when Roblox ships them.
- **Docs as a hosted MCP server.** The site is static; a hosted server needs
  running. Bundling the docs in the package works offline and matches the
  installed version.
