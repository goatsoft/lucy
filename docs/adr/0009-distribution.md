# 0009: Copy-in CLI plus a Wally package

- Status: accepted
- Date: 2026-10-30

## Context

shadcn's core idea is that you own the code: components are copied into your
project, not imported from a black box. Roblox developers also expect Wally.

## Decision

- `registry.json` lists core files, specs and every component with its
  dependencies (Dialog and Toaster need Button).
- `scripts/add.luau` (Lune) copies core plus the requested components and their
  dependencies into a project, keeps files you edited unless `--overwrite`, and
  regenerates an `init.luau` index of what is installed.
- The same source is published to Wally as `goatsoft/lucy` for people who want a
  normal dependency. Specs are excluded from the package.

## Consequences

- Copied components require each other by relative path (`script.Parent.Parent.Core`),
  so the folder layout `Core/`, `Components/`, `Testing/` is part of the contract.
- `App` discovers optional services (Toaster) with `FindFirstChild`, so a copy
  without them still works.
