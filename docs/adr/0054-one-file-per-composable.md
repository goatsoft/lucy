# 0054: One file per composable

- Status: accepted
- Date: 2026-11-22

## Context

Every composable lived in `src/Composables/init.luau`, twenty of them in about 1,250 lines, with
one spec file of about 1,300. Components and core parts are one module each. Finding a composable,
reviewing a change to one, or seeing what one depends on meant scrolling one long file, and adding
`useFit` grew it again. JB asked for them to be separate files, as everything else is.

## Decision

- Each composable is its own module, `src/Composables/useX.luau`, returning the function. The
  constants and types it owns sit in its file (`useFit`'s floor, `useDrag`'s `Drag`).
- `requireOwner`, the owner check every composable makes, is its own module beside them.
- A composable that builds on another requires it directly (`useFit` requires `useSize`).
- `src/Composables/init.luau` is only the index: it requires each module and returns them in one
  table, and re-exports the public types (`FocusZone`, `DragOptions`, `Drag`, `Reveal`, `Count`).
  `Lucy.use*` and every `require(...Composables)` are unchanged.
- Specs are one per composable too (`useX.spec.luau`); one that covers two that go together keeps
  both (`useDensity.spec` covers `useMetric`, `useReveal.spec` covers `useCount`).

## Consequences

- A new composable is a new file plus one line in the index. Nothing for games changes.
- `FIT_MIN` is no longer on the Composables table: it is `useFit`'s own default (0.6), documented
  on its page.
