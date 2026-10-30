# 0019: Shared component specs, shared getter bindings, sources in the node

- Status: accepted
- Date: 2026-10-30
- Amends: 0018 (the shape of `Component.mount`), 0014 (effect node layout)

## Context

ADR 0018 accepted a higher mount cost for allocation free updates, and asked
that the mount cost be kept down where it can be without losing anything. After
544df7d a Button still cost about 8.3 KB of Luau heap to mount. Profiling showed
three avoidable costs:

- **A new spec per mount.** Every `X.new` built its spec table, its `defaults`
  table and a fresh `render` closure capturing that mount's props, then threw
  the spec away.
- **One effect per binding, even when bindings share a getter.** Button binds
  `Interactable` and `Selectable` to the same `enabled` getter: two effects,
  two closures, two nodes, both reading the same key.
- **A separate sources table per effect.** Every effect and computed carried
  `sources = {}` beside its own fields (about 48 B with one source).

## Decision

1. **`Component.mount(spec, props)`.** A spec is built once at module level and
   shared by every mount of that kind. `render` reads per mount props from
   `h.props`. The one table form, `mount({ ..., props = props })`, still works.
   Every component except Dialog and Toaster uses the shared form (those two
   capture other per mount locals and are mounted rarely). `Lucy.Spec` is
   exported for typing specs.
2. **One effect per getter.** While Element reads an element's props, getter
   valued properties and keyed tags are gathered on a module stack, then bound
   once per distinct getter: properties and tags that share a getter run it
   once, in one effect. A nested element made while a getter runs binds above
   the entries still being bound and pops its own. If reading the props errors,
   the stack is popped before the error is raised again.
3. **Sources live in the node.** Effects and computeds keep the sources they
   read in their own array part (`node[1]`, `node[2]`...). `unlink` clears from
   the end, so the array keeps its capacity for the next run. An effect node is
   `{ state, fn, owner }` plus its sources (and `onCleanup` when `fn` takes
   one).

## Consequences

- Mount heap: 100 Buttons 867 to 745 KB, 100 Switches 1,407 to 1,260 KB, a keyed
  list of 1,000 2,207 to 2,160 KB, 1,000 bound effects 408 to 361 KB. Update
  suites measured side by side with the previous version are unchanged and still
  allocate nothing.
- Specs: an effect reading one ref stays under 290 B; Element runs a getter once
  for every property and tag bound to it; one shared spec mounts twice with
  different props.
- Component authors must read per mount props from `h.props` in a shared spec,
  never from an upvalue of `new`. The docs, guide and development pages show
  the shared form.

## Alternatives considered

- **Per kind handle metatables** (moving `kind` and per mount methods such as
  `click` off the handle). Saves a little more per mount; left for later, as it
  changes how components add methods.
- **Storing a single source inline on effects.** Ambiguous with key nodes and
  arrays, and would allocate on reruns.
- **One effect per element.** Rejected in 0018 and still rejected: it re-runs
  every binding of an element when one value changes.
