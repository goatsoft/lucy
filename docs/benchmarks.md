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
| Mount a keyed list | Lists | 1,000 | 22.85 | 26.78 | 5219 |
| Edit 100 rows, one write each | Lists | 1,000 | 0.55 | 0.65 | 25 |
| Reverse a keyed list | Lists | 1,000 | 7.73 | 10.27 | 331 |
| Append 100 rows | Lists | 1,000 | 3.75 | 5.31 | 781 |
| Clear a keyed list | Lists | 1,000 | 10.29 | 14.71 | 1258 |
| Destroy a mounted list | Lists | 1,000 | 12.25 | 15.37 | 1260 |
| HUD frame: 50 values, 200 labels | HUD | 200 | 0.50 | 0.64 | 42 |
| One value, 1,000 readers | HUD | 1,000 | 2.81 | 3.55 | 172 |
| Mount Buttons | Components | 100 | 5.20 | 6.05 | 1247 |
| Toggle Switches | Components | 100 | 3.70 | 9.51 | 968 |
| Ref to computed to effect | Reactive core | 10,000 | 11.80 | 11.99 | 2188 |
| Diamond: 1 ref, 1,000 computeds | Reactive core | 1,000 | 0.73 | 0.88 | 110 |
| Mount 1,000 bound effects | Reactive core | 1,000 | 0.97 | 1.09 | 705 |

Medians move by up to about 15% between runs on the same machine.

## What the numbers mean

- **Updates are fine-grained.** Editing one row of a 1,000-row list costs about
  5.5 µs, and only that row's label runs again. A busy HUD frame, 50 values
  feeding 200 labels in one batch, takes 0.5 ms: about 3% of a 60 FPS frame.
- **A bound label costs about 3 µs to update.** One value read by 1,000 labels
  updates all of them in 2.8 ms.
- **The reactive core is cheap.** A write that flows through a computed into an
  effect takes about 1.2 µs. A computed in a 1,000-node diamond costs under 1 µs,
  and the effect at the bottom runs once.
- **Mounting is where the time goes.** A keyed row (a TextLabel with a bound
  text) takes about 23 µs and about 5 KB of Luau heap to build. Most of that is
  creating and parenting the instance. Build long lists once and update them,
  rather than rebuilding them.
- **Keyed lists keep their rows.** Reversing 1,000 rows moves every instance
  instead of rebuilding it, in about a third of the time it takes to mount them.
- **Components do more than bare instances.** A Button mounts in about 52 µs. A
  Switch toggle takes about 37 µs, and that includes starting the thumb's tween.

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
