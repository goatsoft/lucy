# 0017: A living state tree: app state and component state as one graph

- Status: proposed
- Date: 2026-10-30
- Amends: 0004 (keeps its API and guarantees, replaces its copy-on-write mechanism)

## Context

ADR 0004 made `AppState` a path-addressed, copy-on-write store. Every component
keeps its state under `ui.<id>`, so the app can drive any component by path with
no reference to it (`app.state:set("ui.quit.open", true)`). That addressability
is the store's whole point, and it stays.

The mechanism does not scale. The 2026-10-30 benchmarks found that one write to
one component's state costs O(number of mounted components), twice over:

- **Copy-on-write clones every table on the path.** `ui` holds an entry for
  every mounted component, so writing `ui.switch3.checked` clones a table with
  one key per component. With about 100 components that is about 4 KB of heap
  per write, and it grows with the screen.
- **Every subscriber is checked on every write.** Each component subscribes to
  its own `ui.<id>`, so a write walks the whole subscriber list and reads two
  paths per subscriber. The snapshot copy of that list was removed in 4b1305a;
  the O(subscribers) scan remains.

Toggling 100 Switches bound to one ref costs 2.9 ms and 519 KB, and almost all
of it is this store, not the Switch. A Switch on its own now does a tag flip and
replays a prebuilt tween.

There is also a second, quieter cost: **the reactive core (ADR 0014) and the
store are two separate change systems** joined by a bridge. A component prop
given as a ref is copied into the store by an effect, and store changes are
copied back to writable refs in `Component.mount`. `app.state:ref(path)` is a
subscription feeding a ref feeding a writable computed. Two sources of truth,
synchronised by hand, in both directions.

### What other libraries do

| Approach | Examples | Write cost | Snapshot / identity | Notes |
|---|---|---|---|---|
| Immutable tree, global subscriber loop | Redux, Rodux, Reflex, Lucy today | O(path width) copies + O(subscribers) | Free: the state is the snapshot | react-redux's signals work names the O(n) subscriber loop as the dominant per-dispatch cost in large apps, and moves to path-level signals diffed between trees. |
| Persistent data structures (HAMT) | Immutable.js, Clojure | O(log32 n) node copies | Free | Updates still allocate a path of trie nodes; reads go through the trie; values are no longer plain tables. |
| Normalised slices | Redux "normalising state shape" | Smaller constant, same order | Free | A layout discipline, not a fix: the slice holding all components is still copied. |
| Atoms, no tree | Jotai, Nanostores, Charm (Roblox) | O(1) | Per atom only | Fast and composable, but there is no path to address "component X's open flag" from anywhere: that is exactly what ADR 0004 exists for. |
| Mutable deep proxies, lazy per-key signals | Solid stores, Vue `reactive`, Svelte 5 `$state`, Lucy.reactive | O(1) | None, or an explicit `snapshot()` copy | Fine-grained and cheap. Svelte and Solid treat a plain copy as a separate, explicit operation. |
| Mutable tree, versioned lazy snapshots | Valtio, mobx-state-tree | O(depth) version bumps | Snapshot built on demand, cached per version, unchanged subtrees shared | Valtio builds a snapshot only when one is asked for, and tracks changes with nothing more than a version number. MST keeps immutable, structurally shared snapshots of a living tree. |
| Per-node listeners | Legend-State, MST | Only affected listeners run | n/a | Legend-State keeps a listener set on each node, so a change calls only the listeners on that path. |
| Optional two-way binding | Vue `defineModel` | n/a | n/a | If the parent binds a value, the component's ref *is* that binding; if not, it behaves like an ordinary local ref. |

The best ideas are complementary, and none of the libraries above combines them
with path-addressed component state: a **living tree** (O(1) writes), **versioned lazy
snapshots** (keep 0004's "a value you read earlier never changes"), **per-node
subscriptions** (notify only what changed), and **`defineModel`-style aliasing**
(a bound ref *is* the component's state, not a copy of it).

## Decision

`AppState` becomes a living tree whose every value is a source in the reactive
core. One graph, one source of truth, addressable by path from anywhere.

### 1. The tree is live, and every key is a lazy source

- The store holds plain tables and mutates them in place. Each table node
  carries a `version` and a lazily created source per key, the same mechanism
  as `Lucy.reactive` (Solid and Svelte create these lazily, so memory follows
  what is observed rather than how big the state is).
- A write to `a.b.c` walks the path (O(depth)), assigns the key, notifies that
  key's source, and bumps `version` on each ancestor. No table is copied.
- It is a tree, not a graph: a table lives in one place. Assigning a live table
  that is already in the tree elsewhere is an error in dev builds; the caller
  clones. Snapshots are always accepted, since `set` copies their contents in
  (so the read, clone, edit, write pattern in `SceneManager` and `Toaster` keeps
  working).
- `set(path, table)` **reconciles** into the existing node by key instead of
  replacing it: unchanged leaves notify nothing. Replacing `scenes.stack` with an
  equal list is a no-op. Arrays reconcile by index plus length.

### 2. Reads return frozen snapshots, built lazily and shared

- `get(path)` on a leaf returns the value: O(depth), no allocation.
- `get(path)` on a table returns a **frozen snapshot** (`table.freeze`). Each
  node caches its last snapshot with the version it was built at. A snapshot is
  rebuilt only if the version moved, and it reuses the cached snapshots of
  unchanged children. Cost is O(width of changed tables), paid on read, only by
  callers who read tables.
- 0004's guarantee holds and gets stronger: a snapshot you hold never changes,
  and trying to mutate it now throws instead of silently corrupting the store
  (today `get` hands out the store's own tables).

### 3. Subscriptions live on nodes

- `subscribe(path, fn)` registers on the node at `path`, created on demand even
  if the value is nil. There is no global list.
- A write to `a.b.c` notifies subscribers on `a.b.c`, on its ancestors (`a.b`,
  `a`, root), and on any subscribed descendants when a table under it was
  reconciled. Cost is O(depth + subscribers actually affected), never
  O(all subscribers).
- `fn(new, old)` keeps its signature. Leaf subscribers get plain values. Table
  subscribers get snapshots; a node with a subscriber keeps its snapshot current,
  so `old` is always available. That is the one place a write pays O(width):
  watching a whole large table is an explicit, documented cost.
- Subscriptions run through the reactive scheduler, so `state:batch` and
  `Lucy.batch` are the same thing: one notification per subscriber per batch,
  synchronous at the end, as today.

### 4. `state:ref(path)` returns the node's own source

- No subscription and no mirror ref: the accessor reads the key's source
  (tracked) and writes the path. `app.state:ref("player.coins")` costs what a
  `Lucy.ref` costs.
- `app.state.root` exposes the tree as a reactive proxy, so
  `app.state.root.player.coins += 1` is tracked and addressable, the same object
  `ref`, `get`, `set` and `subscribe` see.

### 5. Component state is a mounted node, and bound refs are aliases

This is the cross-over between app-level and component-level state.

- `Component.mount` creates the node `ui.<id>` and keeps a direct handle to it.
  `handle:get(key)` and `handle:set(patch)` touch that node with no path parsing
  and no `ui` lookup.
- A state key given a **writable ref** (a ref, a writable computed, another
  path's `state:ref`) is **aliased**: the node's key *is* that source, as with
  Vue's `defineModel`. `app.state:set("ui.sw.checked", true)`, `handle:set`, a
  click and the parent's ref all write the same source. The two copy effects in
  `Component.mount` (prop to store, store back to ref) are deleted, along with
  the ping-pong guards they need.
- A state key given a **read-only source** (a getter or plain computed) becomes
  a **derived key with local override**: it follows the source, a local write
  overrides it, and the source's next change wins again. This is exactly the
  behaviour documented in Component.luau today, now built into the source.
- An unbound key is a plain local source, seeded from defaults, then props, then
  whatever the app wrote to `ui.<id>` before mount (0004's "saved settings win"
  rule is unchanged).
- Components get per-key reactions: `spec.update` keeps working (driven by the
  node, with `previous` as today), and a new `spec.watch = { checked = fn, ... }`
  runs one function per key that changed. New components use `watch`, so they
  are incremental by construction, which is what the Switch now does by hand.
- Unmount removes `ui.<id>` (unless `persist`), disposing its sources. Aliased
  refs belong to their owner and survive.

### 6. Compatibility

Public API is unchanged: `get / set / merge / update / remove / subscribe /
batch / scope / ref`, paths, reserved roots, synchronous notification, and
"a failing subscriber never stops the others". Observable differences, all of
them fixes:

- `get` returns frozen tables. Code that mutated a table it got from the store
  (a bug today) now errors. Lucy's own `SceneManager` and `Toaster` already
  clone before editing.
- Writing a value equal to the current one, including an equal table, notifies
  nobody. Today a new table with the same contents notifies everyone below it.
- Snapshots of unchanged subtrees keep their identity across writes elsewhere,
  as today.

## Consequences

- A component write is O(depth), independent of how many components exist. The
  `ui` table is never copied, the subscriber list is never scanned.
- One change system. The store, `Lucy.reactive`, refs and component state share
  the reactive core's scheduler, batching, ownership and glitch-free updates.
  Anything in the store can be bound directly: `Text = app.state:ref("ui.hp.value")`.
- Snapshot cost moves to reads, and only to reads of tables that changed. Code
  that reads or subscribes to a big table (all of `ui`, a 1,000-item inventory)
  pays O(width) per change; the docs say so and steer people to leaf paths,
  `each`, or `state:ref`.
- The store must stay a tree. Shared sub-tables are a dev-time error.
- `AppState.luau` and the component state path in `Component.luau` are
  rewritten. This is the riskiest change since ADR 0014, so it lands behind the
  existing 333 specs plus the new ones below, in phases.

### Plan

1. **Benchmarks first.** Add suites that expose the scaling: "Write one
   component with 1,000 mounted", "Subscribe 1,000 paths, write one",
   "Snapshot a 1,000-key table after one write", "Reconcile an equal table".
   Record today's numbers.
2. **Tree and snapshots.** Rewrite `AppState` on lazy key sources: in-place
   writes, versions, frozen snapshots, node subscriptions, reconcile. All
   existing AppState, SceneManager, Toaster and component specs pass unchanged.
3. **Components.** Node handles, aliasing for writable refs, derived keys with
   override for read-only sources, delete the sync effects, add `spec.watch`.
   Move Switch, Checkbox, Input and Dialog to `watch`.
4. **`state.root` and docs.** Reactive proxy over the tree, docs/architecture.md
   and docs/reactivity.md updated, 0004 marked "amended by 0017".

### Baseline

Recorded before any change (phase 1), M1 Max, Studio edit mode, 15 to 30
iterations. The store suites repeat their operation 100 times per run.

| Suite | Median | Heap |
|---|---:|---:|
| Write one component, 10 mounted (100 writes) | 0.55 ms | 116 KB |
| Write one component, 1,000 mounted (100 writes) | 16.3 ms | 3,266 KB |
| Subscribe 1,000 paths, write one (100 writes) | 14.8 ms | 3,220 KB |
| Snapshot a 1,000-key table after one write (100 times) | 0.23 ms | 3,227 KB |
| Reconcile an equal table (100 sets) | 0.07 ms | 14 KB |
| Toggle 100 Switches | 3.2 ms | 519 KB |

One component write: 5.5 µs and 1.2 KB with 10 mounted, 163 µs and 33 KB with
1,000. Mounting 1,000 components is itself quadratic today (each mount clones
`ui` and its subscription joins the global scan): one setup takes about 200 ms.

### Acceptance

- Toggle 100 Switches: at most 60 KB of heap and 1.5 ms (today 519 KB, 2.9 ms).
- Writing one component's key with 10 or 1,000 components mounted costs the same
  within noise, and allocates nothing.
- `get` of an unchanged table allocates nothing; `get` of a leaf allocates
  nothing.
- Ref to computed to effect and the list suites do not regress.
- All existing specs pass; new specs cover reconcile, frozen snapshots, node
  subscriptions, aliasing, derived keys with override, and unmount.

## Alternatives considered

- **Persistent maps (HAMT), as in Immutable.js.** Keeps full immutability with
  O(log32 n) writes, but every write still allocates a path of trie nodes, reads
  get slower, and values stop being plain Luau tables you can iterate. It also
  keeps two change systems. Rejected.
- **Shard `ui` into buckets, or normalise.** Divides the constant and keeps the
  order. A layout trick that every future feature would have to respect.
  Rejected.
- **Path-indexed subscriptions on the immutable store** (the react-redux signals
  approach). Fixes the subscriber scan but not the copy. Worth it alone, not
  enough.
- **Separate component stores plus an app store** (a store per component, as with
  atoms or per-feature stores). O(1) writes, but "set component X's state from
  anywhere" needs a registry and a sync layer between the two, which is the
  cross-over problem again. Rejected.
- **A mutable store with no snapshots** (deep proxies alone). Fastest, but breaks
  0004's guarantee that what you read earlier never changes, which subscribers
  and `previous` rely on. Versioned snapshots keep the guarantee at read-time
  cost only.
