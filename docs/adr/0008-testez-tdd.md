# 0008: TDD with TestEZ, run in Studio and CI

- Status: accepted
- Date: 2026-10-30

## Context

The brief asked for TDD with TestEZ (or TestService). TestEZ is archived by
Roblox; Jest-Lua is its maintained successor. UI behaviour (styling, layout,
focus) can only be verified inside the engine.

## Decision

- TestEZ 0.4.1 as a Wally dev dependency. Specs are `*.spec.luau` next to the code.
- Write the spec first, watch it fail, then implement.
- `tests/Runner.luau` runs all specs and returns a summary; it is called from the
  Studio command bar or the Studio MCP in the dev place (`test.project.json`,
  served on port 38574), and by `scripts/run-tests.server.luau` for headless
  `run-in-roblox` in CI.
- `src/Testing/Harness.luau` gives specs a disposable App with a fixed desktop
  input profile, device capability sets, `flush()` for styling and `styled()`
  to read resolved values.

## Consequences

- Styling assertions must read `GetStyled` and wait a few frames.
- TestService is not used directly; TestEZ gives describe/it structure and
  lifecycle hooks that TestService lacks.

## Alternatives considered

- **Jest-Lua**: maintained and richer, more setup. Migration is mechanical
  (`expect(x).to.equal(y)` to `expect(x).toBe(y)`) if TestEZ becomes a problem.
