# 0040: Text animations are composables; stateless helpers are Utils

- Status: proposed
- Date: 2026-11-09

## Context

Text learned to type itself out (`reveal`) for dialogue, then games needed a
number that counts up for XP, coins and scores. Both were first written inside
`Components/Text`, with a thousands formatter beside them. But neither belongs
to Text: a label built with `Lucy.new`, a button's caption or a world board may
want the same, and the formatter has no state at all.

## Decision

- **Animations with state are composables:** `Composables.useReveal(text,
  { rate, rich })` returns `{ visible, revealing, skip, done }` (bind
  `visible` to MaxVisibleGraphemes); `Composables.useCount(value,
  { seconds, from })` returns `{ value, counting, skip, done }`. Both need an
  owner, run on `Animate.drive` and fire a `Signal` when they finish. Exported as
  `Lucy.useReveal` and `Lucy.useCount`.
- **Text keeps its shortcuts** (`reveal`, `value`, `count`, `from`, `format`,
  `skipReveal`, `skipCount`, `Revealed`, `Counted`, the `revealing` and
  `counting` state keys), built on those composables, so nothing changes for
  its callers.
- **Stateless helpers live in `src/Utils/`:** plain functions with nothing to set
  up or clean up. The first is `Utils/Format` (`Format.number(n, decimals?,
  separator?)`), exported as `Lucy.Format`. Text's default `format` is
  `Format.number`.
- The rule: anything with state over time is a composable (it needs an owner);
  anything that maps a value to a value is a util.

## Consequences

- Any label can type out or count up without becoming a Text.
- `Text.formatNumber` never shipped; `Lucy.Format.number` replaces it.
- New helpers have an obvious home, and composables stay the only place state
  over time lives outside components.
