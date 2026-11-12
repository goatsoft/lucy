---
title: Boards
description: Lucy.Boards keeps a game's leaderboards on the server, all time, this week and today, with each player's own rank, their names, the request a client asks with, and rows published for everyone. Every method and option.
order: 6
---

# Boards

A leaderboard needs more than an OrderedDataStore. A board for this week has to
start again every Monday, and the Leaderboard shows names, not user ids. A
player also wants their own rank, which an OrderedDataStore can't give you for
one key. And the client needs a request to ask for it all, which the server has
to check.

`Lucy.Boards` does that on the server, on top of the game's
[data queue](data-queue.md). For a whole example, with the dialog and a wall,
see the [Leaderboards recipe](../recipes/leaderboards.md).

## Make the boards

Make one, beside the queue and the [server](server.md), and list the boards:

```luau
local boards = Lucy.Boards.new({
    queue = data,
    server = server,
    boards = {
        combo = { store = "BestCombos", periods = { "all", "week" } },
        hype = { store = "HypeEarned", kind = "total" },
        coins = { store = "CoinsToday", kind = "total", periods = { "day" } },
    },
})
```

Each board names its OrderedDataStore and says how it keeps values:

| Field | Default | What it does |
|---|---|---|
| `store` | | The OrderedDataStore's name. Required |
| `kind` | `"best"` | `"best"` keeps each player's highest value; `"total"` adds up what is posted |
| `periods` | `{ "all", "week" }` | Which lists the board keeps: `"all"`, `"week"`, `"day"` |

`"all"` is the store itself. `"week"` is the same store in scope `w<week>`,
and a new week starts empty on Monday at 00:00 UTC. `"day"` is scope `d<day>`,
starting at 00:00 UTC. Nothing needs resetting.

## Post a value

```luau
boards:post(player, "combo", 42)           -- best: kept if it is higher
boards:post(player, "hype", 120)           -- total: added
boards:set(player, "combo", 18, "week")    -- this value as it is, in one period
boards:set(player, "combo", 42)            -- in every period the board keeps
```

`post` writes to every period the board keeps. `set` is for a game that keeps
the numbers itself, such as a profile with this week's stats. Values are rounded
down, and anything 0 or below is ignored. Writes go through the data queue, so
posting on every hit costs one write to a key every few seconds. `player` can be
a Player or a user id.

## Read a board

```luau
local answer = boards:get("combo", "week", player)
-- answer.board, answer.period
-- answer.rows: { { userId, name, value, rank } }, best first, the top 20
-- answer.me: the player's own row, with rank when they are in the top 100

local rows = boards:top("combo", "all", 5)  -- just the rows
```

`get` reads the top 100 once and answers from that page after, refreshing it
in the background every 60 seconds (the queue's `ttl`). The first read yields.
This server's own writes are in it straight away. A player past the top 100
gets their own value with no rank, so a Leaderboard shows its `unranked` text
("100+").

Names come from the game's `name` function first (bots, a demo board), then the
player if they are in the server, then `Players:GetNameFromUserIdAsync`. Each
one is looked up once.

## The request

With `server`, the boards answer `boards.get` for every client:

```luau
-- on the client
local answer = app.server:call("boards.get", "combo", "week")
```

The request checks the board and the period against the list, and the server
passes the asking player, so `answer.me` is always theirs. A board or period the
game doesn't keep is an error. The client gets it as a failed call.
[useRequest](composables/use-request.md) keeps that answer as state for a
Leaderboard.

## Publish for everyone

```luau
boards:publish("combo", { count = 5 })        -- at shared.boards.combo
boards:publish("hype", { period = "week", path = "shared.walls.hype", every = 30 })
boards:refresh()                              -- read them all again now
```

`publish` keeps a board's top rows in the server's state, where every player
sees them under `server.*`: a wall, a HUD, the crown over the leader's head. It
reads now and again every `every` seconds. `refresh` reads every published
board again at once, after a round ends say.

## Options

| Option | Default | What it does |
|---|---|---|
| `queue` | | The game's `Lucy.DataQueue`. Required |
| `boards` | | The boards, by id (see above) |
| `server` | | A `Lucy.Server`: answers the request, and `publish` writes to its state |
| `request` | `"boards.get"` | The request's name, `false` for none |
| `top` | `20` | Rows `get` returns |
| `depth` | `100` | How far down a player's own rank is looked up |
| `name` | | `function(userId)` returning a name, or `nil` to look it up |
| `now` | `os.time` | The time in seconds, for specs |

`boards:destroy()` stops the request and the publishing.

## Offline

With no DataStores (an unpublished place, or API access off in Studio) the
queue keeps everything in memory, so posting, ranks, the request and publishing
all work for the session.
