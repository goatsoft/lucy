# 0035: A DataStore queue on the server

- Status: accepted (JB, 2026-11-02)
- Date: 2026-11-02

## Context

The server half (ADR 0033) keeps a game's live state, but saving it is still each
game's own code, and the easy way to write it goes wrong. Dance Lab shows how:

- Its leaderboards write a player's lifetime hype with `SetAsync` on every cheer.
  The engine takes one write per key about every 6 seconds; the rest wait in its
  request queue, which fills ("request was added to queue").
- Its venue boards read three sorted stores every 15 seconds: 12 sorted reads a
  minute against a budget of 5 plus 2 per player.
- Its `BindToClose` saves every profile and waits up to 25 seconds. The save sits
  behind the full queue, so stopping a Studio session takes most of that, and
  starting the next one before it ends hangs.

None of this is particular to Dance Lab: every game that saves on change, reads
leaderboards for a board, and saves on close meets the same limits.

## Decision

- **`Lucy.DataQueue.new(options)`** on the server owns a game's DataStore traffic.
  `queue:store(name, scope?)` and `queue:ordered(name, scope?)` give handles.
- **Writes are queued and coalesced.** `set(key, value)`, `update(key, fn)` and
  `remove(key)` return at once. A key keeps one pending write: a later `set`
  replaces it, an `update` composes onto it. The queue sends a key's write no
  sooner than `keyGap` seconds (6) after its last one, and only while the
  engine's budget for that request type (`GetRequestBudgetForRequestType`) has
  room. A failed write is retried with backoff, then dropped with a warning.
- **Reads are cached.** `get(key)` answers from a pending write first (a game
  reads what it wrote), then from a cache kept `ttl` seconds (60), then from
  the store. `ordered:top(count)` keeps the sorted page for `ttl` seconds; once
  there is a page it answers at once and refreshes in the background when it is
  stale, with the pending writes merged in, so a board shows a new score at once.
- **Closing.** The queue binds `BindToClose` and writes what is pending, waiting
  at most `closeTimeout`: 5 seconds in Studio, 25 live. `queue:flush(timeout)`
  does the same on demand (a player leaving).
- **Offline.** When the place cannot reach DataStores (unpublished, or API access
  off in Studio) the handles keep everything in memory and say so once.
- **Specs** inject the service, the clock, the scheduler and `spawn`, so every
  step is deterministic; `autoRun = false` steps only on `queue:step()`.

## Consequences

- Saving on every change is safe: the queue sends the latest value when the
  engine has room, and a busy key never blocks the others.
- A write can land up to `keyGap` seconds after the call, and a cached read can
  be `ttl` seconds old. Games that need a value right now pass `{ fresh = true }`.
- Writes still pending when `closeTimeout` runs out are lost, as they would be
  with a hand-written `BindToClose`; the queue warns with how many.
- It is not session locking. Games that need it (trading, money) still use
  `UpdateAsync` through `update` and handle conflicts themselves.

## Alternatives considered

- **A generic rate-limited task queue.** Rejected for now: the hard parts are
  DataStore specific (the per-key gap, per-type budgets, read-your-writes,
  sorted pages), and a generic queue would leave each game to rebuild them.
- **A third-party profile library.** Rejected: Lucy has no runtime dependencies,
  and the queue is smaller than one.
- **Fixing Dance Lab's services only.** Rejected: every game meets the same limits.
