# 0002: Vanilla Luau components with state-bound handles

- Status: accepted
- Date: 2026-10-30

## Context

shadcn-vue builds on Vue's reactivity. Roblox has no Vue port. The options are
React-lua (Roblox's React port), Fusion (a popular reactive library) or plain
Instances. Lucy is copied into games as source (ADR 0009), so every dependency
travels with it, and the code must stay readable for people editing their copy.

## Decision

Components are plain Luau modules that create real Instances. Each `X.new(props)`
returns a handle (`handle.Instance`, `:get`, `:set`, `:destroy`) built by
`Component.mount`, which:

- keeps the component's stateful props in AppState at `ui.<id>` (ADR 0004),
- re-runs the component's `update(handle, state, previous)` when that state changes,
- registers the component's style rules on the theme once per kind (ADR 0003),
- cleans up through a Maid on destroy.

Visuals are set by style rules, never by code, so an instance property set in
code never silently overrides a theme. Code sets behaviour and layout only.

## Consequences

- Zero runtime dependencies; a component is one file you can read top to bottom.
- Reactivity is coarse (whole-component `update`), which is fine at UI sizes.
- No virtual tree: lists that change shape (toasts) reconcile by id by hand.

## Alternatives considered

- **Fusion**: closest to Vue ergonomics, but adds a dependency to every copy and a
  second state model next to AppState.
- **React-lua**: heavy, JSX-less ergonomics in Luau are verbose, and its own state
  conflicts with an app-level store.
