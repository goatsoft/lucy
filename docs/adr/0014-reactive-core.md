# 0014: A fine-grained reactive core with Vue's vocabulary

- Status: accepted
- Date: 2026-10-30

## Context

Lucy ships what the popular Roblox UI libraries do not: a themed component kit,
engine-native styling, input and focus for every device, scenes and app state.
What it lacked was a way to write your *own* UI declaratively. Building
instances and calling `handle:set` is where Fusion and react-lua were ahead.

- **Fusion** has good reactive state and declarative instances, but no
  components. Its 0.3 scopes mean passing a `scope` everywhere and reading with
  `use` or `peek`.
- **react-lua** is a port of React 17. It is familiar and capable, but large, and
  every state change re-renders a component and diffs the result.
- **Iris** is tiny and dependency-free, but immediate-mode and aimed at debug tools.

The goal is Fusion's power, React's ease and Iris's footprint, with no runtime
dependencies.

## Decision

- **Signals, called like functions.** `ref(0)` returns a function: `count()`
  reads, `count(5)` writes. No `.value`, and no auto-unwrapping of refs stored
  inside reactive tables. Chosen by JB over Fusion-style objects and React hooks.
- **Vue's names**, because they are the best-known small reactive vocabulary:
  `ref`, `computed` (with writable `{ get, set }`), `reactive`, `watch`,
  `watchEffect`, `effectScope`, `onCleanup`, `toValue`, `toRaw`, `isRef`,
  `trigger`. Lucy adds `batch`, `untrack` and `peek`.
- **A push-pull graph.** A write marks direct observers DIRTY and the rest of the
  graph CHECK. Effects refresh by re-validating computed sources and run only if
  a value actually changed. Computeds are lazy and cached. Diamonds run once with
  consistent values. Effects run synchronously after each write or batch.
- **Ownership instead of scopes.** Effects, computeds, scopes and elements belong
  to whatever was running when they were created. They are disposed when it
  re-runs or stops, so there is nothing to pass around.
- **Reactive tables are proxies.** Reads are tracked per key, iteration and `#`
  through an iterate key. Luau's `table` library uses raw access, so lists
  change through `Lucy.insert` and `Lucy.remove`.
- **Declarative instances.** `Lucy.new "Class" { }` and `Lucy.hydrate(instance) { }`
  bind properties, Vue-style tags, attributes, events (`on`, `changed`, `out`,
  `model`, `instance`) and children (`show`, `each`, getters). Every element has
  a scope. The scope is stopped by `Destroying`, and the instance is destroyed
  when its owner goes away. Hydrated instances are only unbound.
- **Animation as sources.** `spring` and `tween` return computeds. Colours
  animate in Oklab. A single Heartbeat connection runs only while something moves.
- **App state bridge.** `app.state:ref(path)` is a writable computed over a path.
- Each part is one module in Core (Reactive, Element, Animate). There is still no
  runtime dependency.

## Consequences

- Custom UI is declarative and fine-grained. Nothing re-renders, so large lists
  and HUDs stay cheap.
- `table.insert` on a reactive list silently bypasses tracking, so the docs have
  to make `Lucy.insert` and `Lucy.remove` obvious.
- Synchronous effects are predictable and easy to test. Very write-heavy code
  should use `batch`.
- Next: components accept refs and getters for their props, migration guides,
  benchmarks against Fusion and react-lua, and a stories workflow in Studio.
