# 0011: Name the project Lucy

- Status: accepted
- Date: 2026-10-30

## Context

The working name was "UI Kit". Candidates: LucyLua and Lucy.

## Decision

**Lucy.** It reads well in code (`Lucy.App.new()`, `Lucy.Button.new()`), and a
"Lua" suffix is redundant for a Luau library. Wally package `goatsoft/lucy`.
Instance names use the `Lucy_` prefix, logs the `[Lucy]` prefix, and component
tags keep the short `ui-` prefix (`ui-button`).
