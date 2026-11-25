---
title: The data queue
description: Lucy.DataQueue paces DataStore requests to the engine's limits, caches reads, keeps leaderboards and writes what is pending when the server closes. Every method and option.
order: 5
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

For boards with a week that starts again on Monday, each player's own rank and
names, use [Lucy.Boards](boards.md), which keeps them through the queue.

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

## Waiting for one key

Some answers must wait until the save is in the store, such as a purchase's
receipt: telling Roblox it was granted before the profile is written can lose the
item if the server stops. `handle:await(key, timeout)` yields until every write
made to that key so far has landed:

```luau
profiles:set(`u{player.UserId}`, profile)
if not profiles:await(`u{player.UserId}`, 10) then
    return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox asks again
end
return Enum.ProductPurchaseDecision.PurchaseGranted
```

It returns `false` when the latest write gave up after its retries, or when
`timeout` runs out (no timeout: it waits for one or the other). Offline, or for a
key with nothing written, it returns `true` at once. Writes made while it waits
are not waited for.

## Studio

In Studio every store gets a name of its own: `queue:store("Profiles")` is
`Studio_Profiles` there and `Profiles` live. Testing never touches the live
game's data, so a test purchase, a test score or a reset profile stays in
Studio. The queue says so once when it starts, and `queue.prefix` is
`"Studio_"` in Studio and `""` live.

```luau
Lucy.DataQueue.new()                      -- Studio_Profiles in Studio
Lucy.DataQueue.new({ studio = "Test_" })  -- Test_Profiles in Studio
Lucy.DataQueue.new({ studio = false })    -- Profiles in Studio too: the live data
```

The Studio stores start empty, so your first Play in Studio is as a new
player.

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
| `studio` | `"Studio_"` | What store names start with in Studio, or `false` for the live stores |

Specs can pass `service` (a fake DataStoreService), `clock`, `wait`, `spawn`,
`warn`, `inStudio` (whether to act as Studio) and `autoRun = false` (step with
`queue:step()`), so every step is deterministic.

## Profiles: one server at a time

A game with trading, or money that moves between players, needs each player's
data held by one server at a time. Otherwise a player who leaves and joins
another server at once loads what the first has not saved yet, and keeps both
copies of whatever they just traded away. `Lucy.Profiles` does this on top of
the queue.

```luau
local queue = Lucy.DataQueue.new()
local profiles = Lucy.Profiles.new(queue, "Profiles", {
    template = function()
        return { coins = 0, moves = {} }
    end,
})

Players.PlayerAdded:Connect(function(player)
    local profile, why = profiles:load(`u{player.UserId}`)
    if not profile then
        player:Kick(if why == "in use" then "Your data is still saving. Join again in a moment." else "Could not load your data.")
        return
    end
    profile.data.coins += 10 -- change data in place; it saves every minute
end)

Players.PlayerRemoving:Connect(function(player)
    local profile = profiles:get(`u{player.UserId}`)
    if profile then
        profile:release() -- the last save, and let it go
    end
end)

profiles.onLost = function(profile)
    -- another server took it over (this one stalled): the player is on two servers
end
```

| | |
|---|---|
| `profiles:load(key)` | Yields. Claims the profile for this server and answers it, or `nil, "in use"` when another server still holds it after a few tries, or `nil, "failed"` |
| `profiles:get(key)` | The profile this server holds, or `nil` |
| `profile.data` | The game's data. Change it in place |
| `profile:save()` | Queues a save. Every held profile saves every `autosave` seconds by itself |
| `profile:release()` | The last save, letting another server load it |
| `profile:await(timeout?)` | Yields until every save so far has landed |
| `profiles:receipt(profile, purchaseId, grant)` | For `ProcessReceipt`: runs `grant(data)` once per purchase, and answers `true` once that is saved |
| `Lucy.Profiles.commit({ a, b })` | Saves every profile given and waits for all of them: tell players a trade is done only when it answers `true` |

A claim older than `stale` seconds (autosave times three, plus a minute) is a
server that stopped, and is taken over. Options: `template`, `reconcile(data)`
to fill fields added since, `autosave` (60), `stale`, `tries` (6) and `wait`
(2.5) for loads that find the profile held, `receipts` (100 remembered).

## What it does not do

DataStores cannot write two keys as one, so `commit` makes the gap between a
trade's two saves as short as it can, while both profiles are held here so
nobody can load either side elsewhere.
