# AGENTS.md

Instructions for AI agents (and humans) working on Lucy.

## What this is

Lucy is a shadcn-style UI kit and app framework for Roblox in Luau. Read
`docs/architecture.md` first, then the ADRs in `docs/adr/` before changing anything
structural. A structural change needs a new ADR (copy `docs/adr/0000-template.md`).

## Hard rules

1. **No em-dash (U+2014) anywhere**: code, comments, docs, UI copy, commit
   messages. Use a hyphen, comma, colon or middot. Check before finishing:
   `grep -rn $'\xe2\x80\x94' --exclude-dir=DevPackages --exclude-dir=.git .` must print nothing.
2. **TDD**: write or extend the `*.spec.luau` next to the module first, see it fail,
   then implement. Every bug fix gets a spec that would have caught it.
3. **Looks live in style rules, not code.** Components set behaviour and layout from
   code (Text, Visible, Size, Interactable, tags). Colours, fonts, radius, strokes,
   padding and control heights come from `rules` with `$Token` values. A property
   set from code overrides the theme.
4. **State lives in AppState** at `ui.<id>`. Do not keep UI truth in locals.
5. **Every interactive component works with mouse, keyboard, gamepad and touch**:
   `Interactable`/`Selectable` follow `disabled`, there is a `:click()` or `:toggle()`
   path, sizes come from density tokens, and nothing re-enables Roblox's default
   selection image or borders.
6. **Keep scratch files outside the repo** (for example `~/tmp/roblox-ui-kit`), not in
   a gitignored folder inside it.
7. Do not name anything after other people's IP; Lucy is original.

## Layout

```
src/Core/          framework (App, AppState, Theme, Tokens, Oklab, Palette, InputManager,
                   SceneManager, Adaptive, Responsive, Component, Signal, Maid, Context)
src/Components/    one module + one spec per component
src/Testing/       Harness shared by specs
tests/Runner.luau  runs every spec
scripts/           add.luau (copy-in CLI), gen-palette.luau, run-tests.server.luau
registry.json      CLI registry: core files and component dependencies
```

## Running tests

The developer serves Rojo himself: `rojo serve test.project.json` (port 38574).
In the Studio window for the dev place (not any game place), run:

```lua
require(game.ReplicatedStorage.LucyTests.Runner).run()
```

With the Roblox Studio MCP, pick the Studio whose name is the dev place and call
`execute_luau` in the Edit datamodel with the line above. Never run tests in a
game's Studio window.

Styling assertions: use `Harness.flush()` then `Harness.styled(instance, prop)`.
Plain property reads return unstyled values.

## Checks before you say done

- All specs pass (report the counts).
- `luau-lsp analyze` is clean (see docs/development.md).
- No em-dash (rule 1).
- New component: added to `src/init.luau`, `registry.json`, `docs/components.md`.
- Docs and ADRs updated if behaviour or structure changed.

## Shell

On JB's Mac use the mac-shell tool for git and test commands.
