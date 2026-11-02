---
title: The data queue
description: Lucy.DataQueue paces DataStore requests to the engine's limits, caches reads, keeps leaderboards and writes what is pending when the server closes. Every method and option.
order: 9
---

# The data queue

DataStores take only so many requests: about one write to a key every 6
seconds, and a budget per minute for each kind of request. A game that saves on
every change (a cheer, a coin, a score) fills the engine's request queue, and a
server that waits on that queue when it closes holds everyone up. In Studio it
is the slow Stop, and a Play that will not start until the old one has ended.

`Lucy.DataQueue` sits between your game and its DataStores on the server. Writes
return at once and are sent when the engine has room; reads are cached; what is
pending is written when the server closes.

For a whole example, a profile and a leaderboard shown in the App, see
[Save player data](../recipes/save-data.md).

## Make one queue

Make one queue, early, in a server script, and open the stores you use through it:

```luau
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local queue = Lucy.DataQueue.new()
local profiles = queue:store("Profiles")
local topScores = queue:ordered("TopScores")
```

`queue:store(name, scope?)` opens a DataStore; `queue:ordered(name, scope?)`
opens an OrderedDataStore (numbers, with a top list).

## Write as often as you like

```luau
profiles:set(`u{player.UserId}`, profile)

topScores:update(`u{player.UserId}`, function(best)
    return math.max(best or 0, score)
end)

profiles:remove(`u{player.UserId}`)
```

Each key keeps one pending write. A later `set` replaces it; an `update`
composes onto it (and on a pending `set` it runs at once, with no read). The
queue writes a key no sooner than 6 seconds after its last write, and only while
the engine's budget for that kind of request has room, so a busy key never holds
up the others. A failed write is tried again after a second, then two, then
four, and dropped with a warning after three tries. Set `queue.onError` to hear
about it:

```luau
queue.onError = function(info)
    -- info.store, info.key, info.error
end
```

## Read what you wrote

```luau
local profile = profiles:get(`u{player.UserId}`)                   -- yields
local fresh = profiles:get(`u{player.UserId}`, { fresh = true })  -- skips the cache
```

`get` answers from a pending write first, so you always read what you wrote.
Then from what the queue last read or wrote, for 60 seconds. Then from the store.
Pass `{ fresh = true }` when a value must come from the store, such as loading a
profile when a player joins.

## Show a leaderboard

```luau
for rank, entry in topScores:top(10) do
    print(rank, entry.key, entry.value)
end
```

`top(count)` returns the highest values first (`{ ascending = true }` for the
lowest). The first call reads the store and yields. After that it answers at
once from the page it keeps for 60 seconds, refreshing it in the background when
it is stale, so a board can call it as often as it redraws. Writes this server
made since the page was read are merged in, so a new score shows straight away.

## When the server closes

The queue binds `BindToClose` and writes everything pending, waiting at most 5
seconds in Studio and 25 live. Call `queue:flush(timeout)` to do the same at
another time, such as when a player leaves:

```luau
Players.PlayerRemoving:Connect(function(player)
    profiles:set(`u{player.UserId}`, profileOf(player))
    queue:flush(5)
end)
```

`flush` returns `true` when nothing is left. `queue:pending()` counts the writes
still waiting.

## Offline

When the place cannot reach DataStores (it is not published, or API access is
off in Studio) the queue says so once and keeps everything in memory for the
session: `set`, `get` and `top` still work. `queue.offline` tells you.

## Options

| Option | Default | |
| --- | --- | --- |
| `ttl` | `60` | Seconds a read or a top list is kept |
| `keyGap` | `6` | Seconds between writes to one key |
| `retries` | `3` | Tries for a write before it is dropped |
| `retryDelay` | `1` | Seconds before the first retry, doubling after |
| `closeTimeout` | `5` in Studio, `25` live | Seconds `BindToClose` waits |
| `interval` | `0.25` | Seconds between the queue's steps |
| `bindToClose` | `true` | `false` to leave `BindToClose` to you |

Specs can pass `service` (a fake DataStoreService), `clock`, `wait`, `spawn`,
`warn` and `autoRun = false` (step with `queue:step()`), so every step is
deterministic.

## What it does not do

It does not lock sessions. If two servers can write the same player's data at
once (trading, money moved between players) use `update`, and handle what you
find in it.
