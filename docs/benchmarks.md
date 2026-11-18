---
title: Benchmarks
description: Mount, update and teardown costs for big lists, busy HUDs, components and the reactive core.
order: 13
---

# Benchmarks

How long Lucy takes to build UI, update it and tear it down, measured in Studio.
The suites live in `tests/Bench` and anyone can run them.

## Results

Lucy main (unreleased, November 2026) in Roblox Studio 0.747 (edit mode), on an
Apple M1 Max: 30 timed iterations after 5 warmups, the median of five such runs.
Times are per run of the benchmark, not per item. Store suites repeat their
operation 100 times per run.

| Benchmark | Group | Size | Median (ms) | p95 (ms) | Heap (KB) |
|---|---|---:|---:|---:|---:|
| Mount a keyed list | Lists | 1,000 | 15.14 | 21.14 | 2176 |
| Edit 100 rows, one write each | Lists | 1,000 | 0.48 | 0.60 | 0 |
| Reverse a keyed list | Lists | 1,000 | 6.25 | 7.44 | 158 |
| Append 100 rows | Lists | 1,000 | 3.06 | 3.70 | 493 |
| Clear a keyed list | Lists | 1,000 | 6.32 | 7.44 | 0 |
| Destroy a mounted list | Lists | 1,000 | 5.84 | 7.30 | 0 |
| HUD frame: 50 values, 200 labels | HUD | 200 | 0.36 | 0.48 | 0 |
| One value, 1,000 readers | HUD | 1,000 | 1.97 | 2.35 | 0 |
| Mount Buttons | Components | 100 | 4.92 | 6.26 | 784 |
| Mount Switches | Components | 100 | 15.86 | 18.74 | 1515 |
| Toggle Switches | Components | 100 | 0.76 | 0.94 | 17 |
| Set Button text | Components | 100 | 0.36 | 0.46 | 0 |
| Set Button disabled | Components | 100 | 0.63 | 0.77 | 0 |
| Set Button variant | Components | 100 | 0.55 | 0.71 | 0 |
| Write one component, 10 mounted | Store | 10 | 0.08 | 0.09 | 0 |
| Write one component, 1,000 mounted | Store | 1,000 | 0.08 | 0.09 | 0 |
| Subscribe 1,000 paths, write one | Store | 1,000 | 0.12 | 0.15 | 0 |
| Read a table of 1,000 keys after one write | Store | 1,000 | 2.29 | 31.57 | 3205 |
| Set a table equal to the stored one | Store | 1,000 | 2.83 | 2.96 | 0 |
| Ref to computed to effect | Reactive core | 10,000 | 9.79 | 10.07 | 0 |
| 1 ref, 1,000 computeds, 1 effect | Reactive core | 1,000 | 0.56 | 0.64 | 0 |
| Mount 1,000 bound effects | Reactive core | 1,000 | 1.06 | 1.25 | 361 |

Medians move by up to about 15% between runs on the same machine; mount times,
which create the most garbage, move the most. Two move far more, set by when
Roblox collects garbage rather than by Lucy: reading a table after a write
(3.2 MB a run) takes about 0.5 ms, or 5 to 6 ms when a collection lands in it,
and mounting 1,000 bound effects takes about 0.6 ms on its own (`only`) but up to
1.1 ms after the suites before it.

Since October a Switch costs about a third more to mount: it gained sizes (`sm` to
`xl`), a slot for what follows its label, and [named colours](reference/colors.md).

## What the numbers mean

- **Lists and HUDs update only what changed.** Editing one row in a list of
  1,000 costs about 5 µs, and only that row's label runs again. A busy HUD
  frame, 50 values feeding 200 labels in one batch, takes 0.4 ms: under 3% of a
  60 FPS frame. Neither creates garbage.
- **A bound label costs about 2 µs to update.** One value read by 1,000
  labels updates all of them in 2 ms.
- **Components update only what changed.** Setting a Button's text sets
  its `Text` again and nothing else: about 4 µs per Button, no garbage. Disabling one
  (a tag, `Interactable` and `Selectable`) takes about 6 µs. A Switch toggle,
  thumb animation included, takes about 8 µs.
- **Mounting is where the cost is paid.** A keyed row (a TextLabel with a bound
  text) takes about 15 µs and 2.2 KB to build. A Button takes about 50 µs and
  7.8 KB, a Switch about 160 µs and 15 KB, much of it creating and parenting
  instances. Each bound
  state key adds a binding, which is what lets later updates skip everything
  else. Build UI once and update it, rather than rebuilding it.
- **Store writes cost the same however many components exist.** A write to one
  component costs the same with 10 or 1,000 mounted, and it notifies only the
  subscribers on its path.
- **Reading a whole table copies it.** `app.state:get` on a table that just
  changed builds a new frozen copy (about 30 KB for 1,000 keys), and reuses it
  until something inside changes. For values you read often, use
  `app.state:ref`, `app.state.root` or a binding: they read single keys and copy
  nothing. Setting a table equal to what is there compares the contents and
  notifies nobody.
- **Refs, computeds and effects are cheap.** A write that flows through a
  computed into an effect takes about 1 µs and creates no garbage. With 1,000
  computeds reading one ref and one effect reading all of them, each computed
  costs under 1 µs and the effect runs once.
- **Teardown is cheap, and keyed lists keep their rows.** Clearing or destroying
  a list of 1,000 rows unbinds each row before its instance goes. Reversing 1,000
  rows moves every instance instead of rebuilding it.

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

```luau
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
