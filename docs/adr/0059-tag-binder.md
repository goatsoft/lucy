# ADR 0059: Tag Binder (`Lucy.Binder`)

- **Status:** Accepted
- **Date:** 2026-11-27

## Context

Games using `CollectionService` tags to dress worlds (especially with `StreamingEnabled` or map
templates stored in `ServerStorage`) repeat the same boilerplate in every service and client
module: iterate `GetTagged(tag)`, connect `GetInstanceAddedSignal(tag)`, track state per instance,
connect `GetInstanceRemovedSignal(tag)`, guard against templates in `ServerStorage`, and tear down
connections and created instances when an object streams out or is destroyed.

Most hand-written tag loops forget cleanup on removal or accidentally bind tagged templates before
they enter `Workspace`.

## Decision

Add `Lucy.Binder` (`src/Core/Binder.luau`, exported as `Lucy.Binder` and `export type Binder`):

1. **One `Lucy.Maid` per bound instance.** Every bound instance receives a fresh `Maid`; when the
   tag is removed, the instance leaves the scoped `ancestor`, or the binder is destroyed, the `Maid`
   cleans everything up in reverse order.
2. **Function or class form.** `Binder.new(tag, fn, options?)` accepts either a plain function
   `(instance, maid) -> value?` or a table with `.new(instance, maid)`. Destroyable return values
   (`:destroy()` / `:Destroy()`) are given to the `Maid` automatically.
3. **Optional `ancestor` scoping.** Passing `{ ancestor = workspace }` ignores tagged templates in
   `ServerStorage` or `ReplicatedStorage`, binds clones the moment they enter `workspace`, and
   unbinds them when they leave or stream out.
4. **Isolated failures.** A failing constructor cleans its partial `Maid`, warns, and never stops
   other tagged instances from binding.
5. **Lifecycle signals.** `binder.added` and `binder.removed` (`Lucy.Signal`) let callers observe
   bound instances without re-subscribing to `CollectionService`.

## Consequences

- Services can connect every tag binder in `init` (non-yielding) before map-loading services run in
  `start`, removing artificial `needs` dependencies between map loaders and tag dressers.
- Client modules bound with `Lucy.Binder` handle `StreamingEnabled` stream-in and stream-out
  without `WaitForChild` races or leaked connections.
