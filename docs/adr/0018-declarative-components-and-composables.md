# 0018: Declarative components and composables; watchers for side effects only

- Status: accepted (2026-10-30, after plan step 3)
- Date: 2026-10-30
- Amends: 0002 (components still build plain instances, now through Element), 0017 (removes `spec.watch`)

## Context

ADR 0014 gave Lucy a reactive core and Element: `Lucy.new` binds properties,
tags, attributes and events to refs and getters, and owns its bindings through
effect scopes. ADR 0017 made every key of the store, including each component's
`ui.<id>`, a source in that core.

The built-in components use none of it. They build instances with
`Component.create` and push state into them by hand: first through
`update(handle, state, previous)`, then, in 0017 phase 3, through
`spec.watch = { key = fn }`. That is the imperative path, and it was made the
easy one:

- **Watchers restate what a binding says.** `watch.disabled` sets
  `Interactable`, `Selectable` and two tags; a binding says the same thing once,
  next to the instance it describes, and cannot forget the first run.
- **Watchers invite derived state by hand.** A watcher that writes a second key
  or a second instance property when the first changes is a computed written as
  a side effect, with its own ordering and initial-value bugs.
- **Logic is not reusable.** Density sizing, focus scopes and back handlers are
  copied between Switch, Checkbox, Input and Dialog through `Component.onDensity`
  and hand-written pushes and pops.
- **`render` runs outside the component's scope**, so anything reactive created
  while rendering is not owned by the component.

Vue's guidance is the model here: computed for derived values, template
bindings for the view, composables (plain functions that create reactive state
inside the current owner) for reuse, and watchers only for side effects. Its
docs warn against watchers that only derive state. Solid and Svelte 5 say the
same about effects. Lucy already has every primitive needed; what is missing is
the component shape and the rule.

## Decision

### 1. The rule

Derive with `computed` (writable when two-way), bind with refs and getters,
share logic with composables. **Watchers are for side effects only**: work
that is not a property, tag or attribute of an instance the component owns,
such as tweens, callbacks into user code (`onCheckedChange`), input focus
scopes, back handlers and sounds.

The rule goes in AGENTS.md and in docs/components.md. It is enforced in
review: no lint can tell a necessary watcher from a lazy one.

### 2. Components render declaratively

- `render(h)` runs **inside the component's scope**: the scope is created
  before render, and everything render creates (bindings, computeds, effects,
  composables) is owned by the component and stops with it.
- Components build with `Lucy.new` and bind to their state instead of writing
  it into instances:

	```luau
	render = function(h)
		local checked, disabled = h:ref("checked"), h:ref("disabled")
		return Lucy.new("TextButton")({
			Interactable = function() return not disabled() end,
			Lucy.new("Frame")({ Tags = { "ui-switch", ["ui-checked"] = checked, ["ui-disabled"] = disabled } }),
		})
	end
	```

- `h:ref(key)` is a writable ref onto the component's own key: the node's
  source, tracked, writing through the store (so bound refs and store
  subscribers see every write). One per key, cached on the handle.

### 3. Composables

- A composable is a plain function named `useX` that creates refs, computeds
  and effects in the current owner and returns them. It needs no new
  machinery: effect scopes already give ownership. Called outside an owner, it
  errors (nothing would ever stop it).
- They live in `src/Composables` and are exported as `Lucy.useX`. The first
  set is what the built-in components repeat today:
  - `useDensity(app)`: the density as a ref (replaces `Component.onDensity`'s
    store subscription).
  - `useMetric(app, token)`: a control size token in pixels, following density.
  - `useBackHandler(app, active, fn)`: registers `fn` on the back stack while
    `active()` is true.
  - `useFocusScope(app, active, options)`: pushes an input focus scope while
    `active()` is true.

### 4. `spec.watch` is removed; `update` is deprecated

- `spec.watch` (0017 phase 3, unreleased) is removed: a dedicated spec key for
  per-key reactions is exactly the invitation this ADR closes. Side effects use
  `Lucy.watch(h:ref("checked"), fn)` inside render.
- `Lucy.watch` stops allocating per change (its callback goes through the
  allocation-free untracked call), so the side-effect path is as cheap as the
  watchers it replaces.
- `spec.update` keeps working until every built-in component is declarative,
  then is removed in the same release.

## Consequences

- Components read as a description of their instances. Side effects stand out
  because they are the only `Lucy.watch` calls left.
- Shared behaviour (density, focus, back) is written once.
- A binding is an effect, like a watcher, so update cost stays per key. Mount
  cost may rise: Element does more per instance than `Component.create`. The
  acceptance numbers below bound it.
- `Component.onDensity` and `spec.watch` go; `update` follows. Pre-0.1.0, so
  no compatibility shims.

### Plan

1. **Infrastructure:** render inside the scope, `h:ref`, remove `spec.watch`,
   allocation-free `Lucy.watch`, the four composables with specs.
2. **Switch, Checkbox, Input, Dialog** rewritten declaratively, existing specs
   unchanged.
3. **The other components** (Badge, Button, Panel, Text, Progress, Separator,
   Skeleton, Stack, Toaster), then remove `update`.
4. **Docs** together with 0017 phase 4: architecture, reactivity, components
   ("Watchers are a last resort"), AGENTS.md rule.

### Acceptance

- Toggle 100 Switches stays at 0 KB and at most 1.5 ms.
- Mount 100 Switches at most 1.25x today (11.8 ms, 1.4 MB, phase 1 baseline).
- All existing component specs pass unchanged.
- No `Lucy.watch` in a built-in component writes an instance property, tag or
  attribute that a binding could own.

### Results (plan steps 1 and 2, 2026-10-30)

Switch, Checkbox, Input and Dialog are declarative; all existing component specs
pass unchanged. Getting there needed core changes that every element and list
row benefits from:

- `effectScope` shares its methods (913 B to 289 B per scope); reactive nodes
  carry only the tables their kind uses, built as one literal.
- `Lucy.watch` on a ref or getter is one effect, no hidden computed (2 KB to
  1 KB), and its callback no longer allocates per change.
- `h:ref(key)` is a lightweight writable accessor over the key's own source, not
  a computed. `useDensity` is one ref per app.
- Element writes properties without a closure per write, and keeps one cleanup
  per instance instead of four.

| Suite | Before | After |
|---|---:|---:|
| Toggle 100 Switches | 0.70 ms, 0 KB | 0.9 ms, 0 KB |
| Mount 100 Switches | 11.8 ms, 1.4 MB | 15.5 ms (13.6 to 17.2), 2.6 MB |
| Mount 100 Buttons (not migrated) | 4.3 ms | 4.6 ms |
| Mount 1,000 keyed rows | 20 to 25 ms, 5.3 MB | 19 to 23 ms, 3.5 MB |
| Clear or destroy 1,000 rows | 94 KB | 47 KB |
| HUD frame, edit 100 rows | 16 KB, 8 KB | 0 KB, 0 KB |

**Open:** Mount Switches is about 1.3x on time and 1.85x on heap, against the
1.25x budget above. What remains is the per-instance cost of elements (a binding
scope and a Destroying hook each, about 1.2 KB) and one effect per bound
property, not anything specific to Switch. Toggle is also slower (0.7 to
0.9 ms per 100, still allocation-free, inside the 1.5 ms target): a toggle now
runs a few more, smaller effects. Options: accept it (mounting is one-off and
updates stay allocation-free); or make child elements of an owned element share
their parent's scope, which would cut most of the per-instance cost for every
component and list row.

**Decided (JB, 2026-10-30): elements share their owner's scope.** An element
created while an owner runs (a component's render, a show branch, an each row,
an effect scope) binds straight into that owner: no scope, `Destroying` hook or
cleanup of its own. The owner keeps one list of the elements it created per
run, registered before their bindings, so when it stops the bindings and slot
rows stop first and then those instances are destroyed. Elements made with no
owner, and hydrated ones, keep their own scope and still stop when destroyed
from outside. The one behaviour given up: destroying an owned element by hand
no longer stops its bindings early; they stop with the owner (show and each do
this for you). An element made in one owner and adopted by a parent in another
lives as long as the owner that made it.

| Suite | Own scope per element | Shared owner scope |
|---|---:|---:|
| Mount 100 Switches | 14.9 ms, 2,605 KB | 15.4 ms (14.2 to 17.4), 2,142 KB |
| Toggle 100 Switches | 0.9 ms, 0 KB | 0.94 ms, 0 KB |
| Mount 1,000 keyed rows | 22.9 ms (19.3 to 23.9), 3,467 KB | 19.6 ms (17.9 to 20.6), 2,536 KB |
| Clear 1,000 rows | 7.9 ms, 47 KB | 7.5 ms, 125 KB |
| Destroy 1,000 rows | 8.9 ms, 47 KB | 7.1 ms, 125 KB |

Heap falls by about a quarter wherever elements are mounted. Mount time for
Switches does not move: profiling puts about 5.6 ms of the 15 in parenting into
a styled GUI (engine work, unchanged since before this ADR) and most of the rest
in one effect per bound property (about 0.5 KB each). Scopes were not the time.
Teardown heap rose by about 80 bytes per row while getting faster; it is a
`gcinfo` delta and moves with GC timing, so it is noted, not chased.

### Results (plan step 3, 2026-10-30)

Badge, Button, Panel, Text, Progress, Separator, Skeleton, Stack and Toaster are
declarative, and `update` is gone from `Component.mount` (with its first-run
error path). Component specs pass unchanged; only Component.spec's own test
components moved from `update` to `render`. Notes:

- Badge, Button and Text check their variant (and size) in render, so an unknown
  one still fails the mount; the tag binding checks later writes.
- Button binds variant and size as one tag getter: one effect, not two.
- Stack and Toaster resolve responsive values through a new composable,
  `useResponsive(app, value)`. Stack binds its layout only when some prop is
  responsive and otherwise resolves it once.
- Toaster renders `Lucy.each` over `app.state:ref("toasts")`, keyed by id. Each
  row follows its toast by id, so an update in place re-binds only what changed;
  the action button is a `show` branch. Skeleton's pulse and Toaster's clock are
  the only effects, and both are side effects.
- `h:ref` is now one closure with a shared descriptor, and the key's write path
  is built on first write (about 560 B to about 300 B per ref).

| Suite | Before step 3 | After |
|---|---:|---:|
| Mount 100 Buttons | 4.97 ms (4.77 to 5.46), 755 KB | 5.7 to 6.4 ms (5.25 to 7.2), 1,334 KB |
| Mount 100 Switches | 15.4 ms, 2,142 KB | 14.2 to 15.1 ms, 1,999 KB |
| Toggle 100 Switches | 0.94 ms, 0 KB | 0.94 ms, 0 KB |
| Mount 1,000 keyed rows | 19.6 ms, 2,536 KB | 20.1 ms, 2,536 KB |

Button mount costs more heap than its single `update` effect did. Profiling one
Button: the base mount is about 2.6 KB, and each bound key adds about 1.4 KB,
most of it the per-key store source created the first time the key is read. That
source is what ADR 0017 trades for: writes and toggles stay at 0 KB and touch
only their readers. Mount Switches stays about 1.2x on time and 1.4x on heap
against the phase 1 baseline (11.8 ms, 1.4 MB).

### Updates: where the cost pays back (2026-10-30)

Mount is one-off; updates run for the life of the component. Writing one key on
each of 100 mounted components, `update` versions (commit d619635, just before
step 3) against declarative ones on the same core:

| Write, 100 components | `update` | Declarative |
|---|---:|---:|
| Button text | 1.86 ms, 48 KB | 0.47 ms, 0 KB |
| Button visible | 1.51 ms, 52 KB | 0.71 ms, 0 KB |
| Button disabled | 1.69 ms, 49 KB | 1.49 ms, 0 KB |
| Button variant | 1.46 ms, 48 KB | 1.09 ms, 19 KB |
| Text text | 0.89 ms, 25 KB | 0.43 ms, 0 KB |
| Text variant | 0.86 ms, 25 KB | 0.89 ms, 8 KB |

`update` rebuilt the component's snapshot and re-set every property and tag on
any write, about 0.5 KB of garbage each time. A binding touches only what reads
the key: text and visibility writes are 2x to 4x faster and allocate nothing.
Variant writes still allocate a little (the tag binding builds its list), and
variants rarely change. The bench now carries `Set Button text` (0.42 ms, 0 KB)
and `Set Button disabled` (0.91 ms, 0 KB).

**Accepted.** The mount budget above is missed on heap (1.4x) and met on time
(about 1.2x). That is the right place for the cost: paid once at mount, in
exchange for faster, allocation-free updates. One effect per element (instead
of per property) was considered to cut mount cost and rejected: it would move
the cost back into every update.

## Alternatives considered

- **Keep `spec.watch` and document restraint.** The shape of the API decides
  what people write; a first-class per-key watcher wins over any paragraph.
- **A lint rule against watchers.** Cannot tell a tween from a lazy derivation.
- **Re-running render functions over a virtual tree.** Simplest mental model,
  but a diff per change and a new rendering layer; fine-grained bindings
  already update exactly what changed.
- **Hooks with call-order rules.** Composables here run once, in render, inside
  a scope; there is no re-run and so no ordering rule to learn.
