# lucy-mcp

An MCP server for coding agents building Roblox UI with
[Lucy](https://lucy.goatsoft.io). It looks at and drives a running Lucy UI in
Roblox Studio, the way a player would, so an agent can check its own work:

| Tool | What it does |
|---|---|
| `studios` | The Studios open now |
| `apps` | The running Lucy apps: theme, input mode, scene, open modal |
| `tree` | Every component on screen, with its id, text, state and flags |
| `state`, `set` | Read and write the app's store |
| `press` | Click a component, or pick a value in a group, tabs, select, slider |
| `focus` | Move focus to a component, as a gamepad player would |
| `overlays`, `actions` | Open dialogs and sheets; action sets and their keys |
| `preview` | Show a story in edit mode, with a picture; without a story, clear it |
| `screenshot` | A picture of the Studio viewport |

`press`, `set` and `focus` take `screenshot: true` to return a picture of the
result. Every tool takes `studio` (an id, or part of the place name) when
several Studios are open.

It reaches Studio through Studio's own MCP server, which must be on (in Studio:
**Assistant**, **...**, **Manage MCP Servers**, **Enable Studio as MCP
server**). It runs Lucy's [Devtools](https://lucy.goatsoft.io/docs/reference/devtools)
there with `execute_luau`. The game's UI is reachable while it runs in Play;
in edit mode, a story shown with `preview` is.

## Running it from a Lucy checkout

Until it is on npm, point the agent's MCP config at the source (Node 24 runs
it directly). For Claude Code, in the game's `.mcp.json`:

```json
{
  "mcpServers": {
    "lucy": { "command": "node", "args": ["/path/to/lucy/libs/mcp/src/cli.ts"] }
  }
}
```

Set `LUCY_STUDIO_MCP` to Studio's MCP binary if it is not where Studio installs
it (`/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP` on macOS; on
Windows the newest `%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe`, untested).

## Developing

```sh
pnpm mcp:test        # from the repo root: node's test runner, with a fake Studio
pnpm mcp:typecheck
```

`src/studio.ts` is the only file that knows Studio's tool names and answers.
`src/luau.ts` writes the Luau each call runs.
