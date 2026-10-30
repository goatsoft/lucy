# 0015: Strict types in every source file

- Status: accepted
- Date: 2026-10-30

## Context

Only `Signal` was `--!strict`; the rest of `src/` ran in nonstrict mode, so the
README could only promise "a typed Luau API". Turning strict mode on everywhere
surfaced about 300 errors, almost all from a few patterns: classes whose `self`
shape was inferred from the first method that touched it, rule lists inferred
from their first entry, `options or {}` inferring an empty sealed table, and
component callbacks with untyped handles.

## Decision

- Every non-spec file in `src/` starts with `--!strict`, and
  `luau-lsp analyze src tests` reports nothing. Specs stay nonstrict (the
  `.luaurc` default), since TestEZ's globals are loosely typed.
- **Classes** (App, AppState, Theme, InputManager, SceneManager) export their
  type as `typeof(setmetatable({} :: Fields, Class))` and write methods as
  `function Class.name(self: Class, ...)`. Constructors that fill fields in
  dependency order (App, Theme) start from `setmetatable({} :: any, Class)`.
- **Maid** spells its type out instead of inferring it: a generic method inside
  an inferred metatable type is instantiated when copied into other modules'
  types, and stops matching itself.
- **Component** exports `Rule`, `Props`, `State`, `Spec` and `Handle`.
  `mount` takes a `Spec` and returns a `Handle`, so `render` and `update` get a
  typed handle. `Handle` and `SceneManager.Scene` keep a `[string]: any`
  indexer because components and games hang their own parts on them.
- Each component declares `local rules: { Component.Rule } = {...}` before
  assigning `X.rules`, so rules with different properties check together.
- `any` stays where values are genuinely dynamic: the app reference inside
  services (avoids a require cycle), the reactive graph's internal nodes,
  user-defined scene definitions and the toast API table.

## Consequences

- The README and site say "strict types throughout" again.
- New modules follow the same pattern (docs/development.md shows it), and CI's
  luau-lsp step now guards strict mode for all of `src/`.
- The package root re-exports the main types (`Lucy.App`, `Lucy.AppState`,
  `Lucy.Theme`, `Lucy.Scene`, `Lucy.Handle`, `Lucy.Props`, `Lucy.Rule`, plus the
  reactive ones), and `scripts/add` writes the same exports into its generated
  index, so games can type their own strict code against Lucy.
