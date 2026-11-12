---
title: Use Lucy with agents
description: Give Claude Code, Codex or Antigravity Lucy's skills, so they build your UI with Lucy's components and rules.
order: 4
---

# Use Lucy with agents

Lucy comes with skills for coding agents. A skill is a folder of instructions
an agent reads when a task needs it, so an agent working on your game builds
with Lucy's components, state and themes instead of guessing. Lucy has three:

| Skill | What it teaches |
|---|---|
| `lucy` | Building UI with Lucy: the App, scenes, app state, every component, styling, input and hotkeys |
| `lucy-icons` | Adding icons, and setting up and running the lucy-icons build |
| `lucy-debug` | Checking UI in Studio with [Devtools](../reference/devtools.md): reading what is on screen, pressing buttons, taking screenshots |

The skills are made from these docs, so they match the version they come with.

To look at and change your game in Studio, agents use Roblox Studio's own MCP
server. Turn it on first: in Studio, open **Assistant**, click **...**, then
**Manage MCP Servers**, and turn on **Enable Studio as MCP server**. The same
panel connects Claude Code, Codex and Antigravity for you. See
[Connect to the Roblox Studio MCP server](https://create.roblox.com/docs/studio/mcp).

## Claude Code

Add the GOATsoft plugin list once, then install Lucy:

```sh
/plugin marketplace add goatsoft/lucy
/plugin install lucy@goatsoft
```

`/plugin marketplace update goatsoft` picks up new versions.

## Codex

```sh
codex plugin marketplace add goatsoft/lucy
```

Then open `/plugins` in Codex, pick **GOATsoft** and install **Lucy**.
`codex plugin marketplace upgrade goatsoft` picks up new versions.

## Antigravity

Antigravity reads skills from `.agents/skills` in your game's folder. Copy
Lucy's skills there, from your game's folder:

```sh
git clone --depth 1 https://github.com/goatsoft/lucy /tmp/lucy
mkdir -p .agents/skills
cp -R /tmp/lucy/plugins/lucy/skills/* .agents/skills/
```

Commit them, so everyone working on the game gets them. Run the same commands
again to update.

## Skills in your game's folder, for every agent

The copy above works for more than Antigravity. Codex reads `.agents/skills`
too, and most other agents read it or can be pointed at it. Claude Code reads
`.claude/skills` instead, so link each skill there:

```sh
mkdir -p .claude/skills
for skill in .agents/skills/lucy*; do
    ln -s "../../$skill" ".claude/skills/$(basename "$skill")"
done
```

Link each skill folder, not the whole `.claude/skills` folder: Claude Code keeps
files of its own there.

## Check it works

Ask your agent something like "add a settings menu with a volume slider and a
music switch". It should find Lucy in your game, use `Lucy.Slider` and
`Lucy.Switch`, bind them to app state and give the menu a `defaultFocus`, without
being told to read anything.

## Inspect and drive UI with lucy-mcp

The repo includes an MCP server at `libs/mcp` (`@goatsoft/lucy-mcp`) so an
agent can inspect a running Lucy app in Studio, read `app.state`, click
buttons, move gamepad focus, open stories in edit mode and take screenshots.
It uses Studio's own MCP server, so keep **Enable Studio as MCP server** on in
Studio's **Manage MCP Servers** panel.

Requires Node 24 or newer. Point your agent's MCP config (for example `.mcp.json`
in your game's folder) at `libs/mcp/src/cli.ts`:

```json
{
  "mcpServers": {
    "lucy": { "command": "node", "args": ["/path/to/lucy/libs/mcp/src/cli.ts"] }
  }
}
```

The server exposes `studios`, `apps`, `tree`, `state`, `set`, `press`, `focus`,
`overlays`, `actions`, `preview` and `screenshot`. In Play mode it reads your
game's live UI; in edit mode it reads any story opened with `preview`.
