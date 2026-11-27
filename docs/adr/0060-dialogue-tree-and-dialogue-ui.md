# ADR 0060: `Lucy.DialogueTree` and `Lucy.Dialogue`

- **Status:** Accepted
- **Date:** 2026-11-27

## Context

Games built with Lucy (Crime Spree, Dance Lab, RPGs) need branching NPC conversations with
portraits, typewriter text, condition gates (both hidden and greyed-out locked choices), world
state memory, and server-authoritative reward/event execution.

Keeping the conversation engine pure and separate from the UI component lets the server run the
exact same tree against persistent player flags (`Lucy.Profiles`) while the client renders the
replicated node snapshot using Lucy's theme tokens.

## Decision

1. **`Lucy.DialogueTree` (`src/Core/DialogueTree.luau`):**
   - Flat node dictionary keyed by `nodeId` (native Luau `ModuleScript`s) supporting Branch and
     Bottleneck, Hub and Spokes, and Priority Stack / Router (`entry = { ... }`) patterns.
   - Pluggable `Blackboard` (`get`, `set`, `has`, `fire`) plus an in-memory helper
     `DialogueTree.blackboard(initial?)`.
   - Choice gates supporting `locked = "hide"` (default) and `locked = "disable"` with
     `lockedReason`, `once = true` tracking, `{var}` interpolation, node cues (`audio`,
     `animation`, `mood`, `meta`), and static `DialogueTree.validate(tree)`.
2. **`Lucy.Dialogue` (`src/Components/Dialogue.luau`):**
   - Themed Lucy component with `$Token` style rules and variants (`default`, `overlay`,
     `inverse`, plus `addVariant`).
   - Drives from a `DialogueTree` runner, a reactive `snapshot` ref (for server-replicated
     conversations), or direct props.
   - Renders actor portraits from a live `Model` (`ViewportFrame`), `UserId`, image asset, or
     speaker monogram, types lines via `Lucy.useReveal`, shows locked choices with `lockedReason`
     badges, fires `onCue(snapshot)`, and integrates with `useBackHandler`.

## Consequences

- Any Lucy game can drop in branching NPC conversations with full theming, controller support,
  and server-authoritative security.
- Static validation catches broken dialogue links during automated tests.
