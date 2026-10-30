---
title: Benchmarks
description: Mount, update and teardown costs for big lists, busy HUDs, components and the reactive core.
order: 3
---

# Benchmarks

How long Lucy takes to build UI, update it and tear it down, measured in Studio.
The suites live in `tests/Bench` and anyone can run them.

## Results

Lucy 0.1.0 in Roblox Studio 0.745 (edit mode), on an Apple M1 Max, 30 timed
iterations after 5 warmups. Times are per run of the benchmark, not per item.

| Benchmark | Group | Size | Median (ms) | p95 (ms) | Heap (KB) |
|---|---|---:|---:|---:|---:|
| Mount a keyed list | Lists | 1,000 | 20.30 | 34.37 | 5282 |
| Edit 100 rows, one write each | Lists | 1,000 | 0.53 | 0.64 | 8 |
| Reverse a keyed list | Lists | 1,000 | 7.84 | 9.05 | 237 |
| Append 100 rows | Lists | 1,000 | 4.15 | 5.08 | 787 |
| Clear a keyed list | Lists | 1,000 | 8.21 | 10.62 | 94 |
| Destroy a mounted list | Lists | 1,000 | 9.25 | 11.85 | 94 |
| HUD frame: 50 values, 200 labels | HUD | 200 | 0.44 | 0.59 | 16 |
| One value, 1,000 readers | HUD | 1,000 | 2.96 | 3.45 | 78 |
| Mount Buttons | Components | 100 | 7.18 | 13.20 | 1031 |
| Toggle Switches | Components | 100 | 2.93 | 3.28 | 519 |
| Ref to computed to effect | Reactive core | 10,000 | 10.34 | 10.60 | 0 |
| Diamond: 1 ref, 1,000 computeds | Reactive core | 1,000 | 0.56 | 0.59 | 0 |
| Mount 1,000 bound effects | Reactive core | 1,000 | 0.93 | 1.41 | 627 |

Medians move by up to about 15% between runs on the same machine; mount times,
which create the most garbage, move the most.

## What the numbers mean

- **Updates are fine-grained.** Editing one row of a 1,000-row list costs about
  5 µs, and only that row's label runs again. A busy HUD frame, 50 values
  feeding 200 labels in one batch, takes 0.5 ms: about 3% of a 60 FPS frame.
- **A bound label costs about 3 µs to update.** One value read by 1,000 labels
  updates all of them in 3 ms.
- **The reactive core is cheap and allocation-free.** A write that flows through
  a computed into an effect takes about 1 µs and allocates nothing. A computed in
  a 1,000-node diamond costs under 1 µs, and the effect at the bottom runs once.
- **Mounting is where the time goes.** A keyed row (a TextLabel with a bound
  text) takes about 20 µs and about 5 KB of Luau heap to build. Most of that is
  creating and parenting the instance. Build long lists once and update them,
  rather than rebuilding them.
- **Teardown is cheap.** Clearing or destroying a 1,000-row list unbinds each row
  before its instance goes, so it costs under 100 KB of heap in total.
- **Keyed lists keep their rows.** Reversing 1,000 rows moves every instance
  instead of rebuilding it, in well under half the time it takes to mount them.
- **Components do more than bare instances.** A Button mounts in about 50 to
  70 µs. A Switch toggle takes about 30 µs, including its thumb animation.
  Component state is copy-on-write, so each write copies the table that holds
  every mounted component's state: that copy is most of a toggle's heap, and it
  grows with the number of components on screen.

## Method

Each iteration runs a suite's `setup` (not timed), then `run` (timed with
`os.clock`), then `teardown` (not timed), so every iteration starts from fresh
state.

- **Time** covers Lucy's own work: creating instances, binding properties and
  running effects. Universal Styling resolves styles a few frames later inside
  the engine, so it is not part of any number here.
- **Heap** is the growth of the Luau heap across `run`, read with `gcinfo()`.
  Roblox cannot force a collection, so treat it as a guide rather than an exact
  allocation count. Samples cut short by a collection are dropped, and the column
  shows n/a if none are left. Memory the engine holds for instances is not
  included.

## Running them

In the Lucy dev place, from the command bar or the Studio MCP:

```lua
local Run = require(game.ReplicatedStorage.LucyTests.Bench.Run)
Run.run()                                -- every suite; prints a markdown table
Run.run({ only = "List" })               -- suites whose name matches a pattern
Run.run({ iterations = 30, warmup = 5 }) -- the settings used above
Run.run({ scale = 0.1 })                 -- smaller sizes, for a quick check
```

`run` returns `{ results, markdown, environment }`. `tests/Bench/Bench.spec.luau`
runs every suite at 1% of its size as part of the normal test run, so the
benchmarks keep working as Lucy changes.

To add a suite, append it to `tests/Bench/Suites.luau` with a `name`, `group`,
`size`, `description`, `setup`, `run` and `teardown`. Keep anything you do not
want timed in `setup` and `teardown`.
