---
title: Contributing
description: Toolchain, the TDD loop, writing a component and releasing.
order: 1
---

# Developing Lucy

## Toolchain

Pinned in `rokit.toml`. Install once with `rokit install`, then `wally install`
for TestEZ (into `DevPackages/`, gitignored).

| Tool | Use |
|---|---|
| rojo | sync source into Studio, build places |
| wally | TestEZ dev dependency, publishing `goatsoft/lucy` |
| lune | `scripts/add.luau` CLI, `scripts/gen-palette.luau` |
| selene / stylua | lint and format |
| run-in-roblox | headless test runs in CI |
| luau-lsp | type checking (editor or `luau-lsp analyze`) |

## Daily loop

1. Serve the dev place (port 38574 is in the project file):
   ```
   rojo serve test.project.json
   ```
2. In Studio, open any place (or `rojo build test.project.json -o ~/tmp/LucyTests.rbxl`
   and open that) and connect the Rojo plugin.
3. Run the specs from the command bar:
   ```lua
   require(game.ReplicatedStorage.LucyTests.Runner).run()
   require(game.ReplicatedStorage.LucyTests.Runner).run({ pattern = "Button" })
   ```
   `run` returns `{ passed, failed, skipped, errors, ok }`.
4. Look at a component without pressing Play:
   ```lua
   require(game.ReplicatedStorage.Lucy).Preview.show("Button", { root = game.ReplicatedStorage.LucyExamples })
   ```
   Press Play for the story browser (`examples/Showcase.client.luau`, mapped into
   StarterPlayerScripts), where every control is clickable.

Keep build output and scratch files outside the repo (for example `~/tmp`).

## TDD

1. Add or extend `X.spec.luau` next to the module. Describe behaviour, not
   implementation.
2. Run it, watch it fail for the right reason.
3. Implement until green, then tidy.

Spec helpers (`src/Testing/Harness.luau`):

- `Harness.app(config)` → `app, cleanup`: an isolated App with a deterministic
  desktop input profile and no engine listeners. Always call `cleanup` in `afterEach`.
- `Harness.caps.desktop / mobile / tablet / console` for `app.input:setCaps(...)`.
- `Harness.mount(app)` → a linked test ScreenGui to parent components into.
- `Harness.flush()` → wait for Universal Styling to apply (a few frames).
- `Harness.styled(instance, prop)` → the resolved value (`GetStyled`).
- `Harness.colorEq(a, b)` → Color3 compare within 1/255.

Gotchas:

- Never assert styled values with plain property reads; they return the
  unstyled value by design.
- Property-changed signals are deferred; `task.wait()` before asserting on a
  value set through a signal (see Input.spec).
- Do not set styled properties from component code; it overrides the theme.

## Writing a component

1. `src/Components/Thing.spec.luau` first.
2. `src/Components/Thing.luau`:
   ```lua
   --!strict
   local Component = require(script.Parent.Parent.Core.Component)
   local Thing = {}
   local rules: { Component.Rule } = {
       { selector = ".ui-thing", priority = 0, properties = { BackgroundColor3 = "$Card" } },
   }
   Thing.rules = rules
   function Thing.new(props: Component.Props?): Component.Handle
       return Component.mount({
           kind = "thing", props = props, rules = Thing.rules,
           defaults = { text = "", visible = true },  -- the keys that live in state
           render = function(h) return Component.create("TextLabel", { Tags = { "ui-thing" } }) end,
           update = function(h, state) h.Instance.Text = state.text; h.Instance.Visible = state.visible end,
       })
   end
   return Thing
   ```
   Annotate the rules list as `{ Component.Rule }` so rules with different
   properties type-check together.
3. Visual properties go in `rules` with `$Token` values; layout and behaviour in code.
4. Sizes that should grow on touch or console come from density tokens
   (`Component.metric(app, "ControlMd")` with `Component.onDensity`).
5. Anything interactive: `Interactable`/`Selectable` follow `disabled`, a
   keyboard path exists (`handle:click()` or `handle:toggle()`), and it works
   inside focus scopes.
6. Add a story, `examples/stories/Thing.story.luau`, with controls for its state
   keys ([stories](stories.md)). `tests/Stories.spec.luau` mounts every story in
   each theme and device.
7. Add it to `src/init.luau`, `registry.json` (with dependencies) and
   `docs/components.md`.
8. Grep for the em-dash character before committing: `grep -rn $'\xe2\x80\x94' .`
   must return nothing.

## Static checks

```
rojo sourcemap test.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau \
  --definitions=@testez=testez.d.luau src tests
selene src tests
stylua --check src tests scripts
```

Every source file starts with `--!strict` and `luau-lsp analyze` must report
nothing. Specs stay in the default nonstrict mode (`.luaurc`) since TestEZ's
globals are loosely typed. Classes declare their type next to the metatable
(`export type AppState = typeof(setmetatable({} :: {...}, AppState))`) and
write methods as `function AppState.get(self: AppState, ...)`.

## Regenerating the palette

```
lune run scripts/gen-palette <path-or-url>   # source URL is in docs/adr/0010
```

## The website

The site in `apps/site` renders this `docs/` folder (everything except `adr/`)
at `/docs/...`, plus a landing page. It needs Node 24 and pnpm.

```sh
pnpm install
pnpm site:dev        # local dev server
pnpm site:build      # prerendered static site in apps/site/dist
pnpm site:typecheck
```

- A Markdown file added under `docs/` becomes a page. Frontmatter `title`,
  `description` and `order` set its sidebar entry; the sidebar groups are in
  `apps/site/src/lib/docs.ts`.
- Links between docs files work on GitHub and on the site; links to ADRs go to
  GitHub.
- Pushes to `main` that touch the site or docs deploy it via
  `.github/workflows/pages.yml`. Deploying never publishes the package.
- If a build logs a hydration mismatch, `LUCY_DEBUG_HYDRATION=1 pnpm site:build`
  explains it in the browser console.

## Releasing

1. Bump `version` in `wally.toml`, note changes in the README.
2. `wally publish`.
