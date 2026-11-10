---
title: Leaderboards
description: Best combo and Hype boards kept in DataStores, all time and this week, a Leaderboards dialog with a tab per board and the dancer's own rank, and a top 5 every player sees.
order: 8
---

# Leaderboards

Club Lucy keeps two boards. **Best combo** keeps each dancer's longest combo,
and **Hype** adds up all the hype they've earned. Each board has an all-time
list and a list for this week. A Leaderboards dialog shows a tab per board, with
All time and This week under the tabs, the top 20, and your own row pinned at
the bottom with your rank. The best combos also go up on the Dance Floor's wall
for everyone.

Three parts of Lucy do the work:

- [Lucy.Boards](../reference/boards.md) on the server keeps the boards in
  OrderedDataStores, works out ranks, names the dancers and answers the
  client's request.
- [useRequest](../reference/composables/use-request.md) on the client asks for
  a board and keeps the answer, asking again when the tab changes.
- [Leaderboard](../components/leaderboard.md) draws it: medals on the top
  three, headshots, and your row.

It builds on the [Game folder structure](folder-structure.md) and the data
queue from [Save player data](save-data.md).

<!-- preview screen trim then="dialog:open()" -->
<figure class="example-preview example-trim"><img class="example-light" src="/images/examples/recipes-leaderboards-light.webp" alt="Leaderboards example" loading="lazy"><img class="example-dark" src="/images/examples/recipes-leaderboards-dark.webp" alt="Leaderboards example" loading="lazy"></figure>

```luau [StarterPlayerScripts/Leaderboards.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local app = Lucy.App.new({ server = true })

local BOARDS = {
    { value = "combo", text = "Best combo" },
    { value = "hype", text = "Hype" },
}
local PERIODS = {
    { value = "all", text = "All time" },
    { value = "week", text = "This week" },
}

local board = app.state:ref("boards.board")
local period = app.state:ref("boards.period")
board("combo")
period("all")
local open = app.state:ref("ui.leaderboards.open")

-- Asks for the board and period picked, again on every pick, only while the
-- dialog is open, and every 30 seconds while it stays open.
local answer
local scope = Lucy.effectScope()
scope:run(function()
    answer = Lucy.useRequest(app, "boards.get", function()
        return board(), period()
    end, { enabled = open, every = 30 })
end)

local list = Lucy.Leaderboard.new({
    rows = function()
        local data = answer.data()
        return if data then data.rows else {}
    end,
    own = function()
        local data = answer.data()
        return data and data.me
    end,
    loading = function()
        return answer.data() == nil and answer.error() == nil
    end,
    unranked = "100+",
    format = function(value)
        return `{Lucy.Leaderboard.formatNumber(value)} {if board() == "combo" then "combo" else "hype"}`
    end,
    empty = "No one on this board yet. Get dancing.",
    height = 360,
})

local dialog = Lucy.Dialog.new({
    id = "leaderboards",
    title = "Leaderboards",
    size = "lg",
    header = {
        Lucy.Stack.new({
            gap = "Space3",
            children = {
                Lucy.Tabs.new({ items = BOARDS, value = board, variant = "line" }),
                Lucy.ToggleGroup.new({ items = PERIODS, value = period, required = true, size = "sm" }),
            },
        }),
    },
    children = { list },
})

app.actions:define("menus", {
    leaderboards = { Enum.KeyCode.L, Enum.KeyCode.DPadRight },
})
app.actions:on("leaderboards", function()
    dialog:toggle()
end)
```

- The dialog keeps one size whatever is on the board, because `height` covers
  the whole board, your row included. The rows scroll inside it.
- While an answer is on its way the rows pulse. A new tab clears the old rows
  straight away, so you never see one board's names under another's tab.
- If the request fails, `answer.error()` has the message and the board shows
  `empty`. The next pick or the next 30-second refresh tries again.
- Board tabs that don't fit scroll sideways, with faded edges. LB and RB move
  between them on a controller, and touch drags them.

## The boards on the server

One `Lucy.Boards` for the server, made beside the queue and the server state.
It answers `boards.get` itself: the client's request is checked against the
boards and periods listed here, so a client can't ask for anything else.

```luau [src/server/Boards.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local Server = script.Parent
return Lucy.Boards.new({
    queue = require(Server.Data),
    server = require(Server.ServerState),
    boards = {
        combo = { store = "BestCombos", periods = { "all", "week" } },
        hype = { store = "HypeEarned", kind = "total", periods = { "all", "week" } },
    },
})
```

- `kind = "best"` (the default) keeps a dancer's highest value. `"total"` adds
  up every value posted.
- A week is the same store under its own scope, and a new one starts on Monday
  at 00:00 UTC with nothing to reset. Add `"day"` to `periods` for a daily
  board.
- `boards.get` answers with the top 20 and the asking dancer's own row, which
  has their rank if they're in the top 100. Past that it has their value and no
  rank, and the Leaderboard shows `unranked` ("100+") instead.

## Post the scores

The game posts a value when something happens. `post` writes to every period of
the board, so the week fills up along with all time:

```luau [src/server/Services/Combos.luau]
local Server = script.Parent.Parent
local boards = require(Server.Boards)

local Combos = {}

-- Called when a dance ends.
function Combos.finish(player: Player, hits: number, hype: number)
    boards:post(player, "combo", hits) -- kept if it's their best
    boards:post(player, "hype", hype)  -- added to their total
end

return Combos
```

Posting is cheap. The data queue writes each dancer's key at most once every 6
seconds, so a dancer who finishes ten dances a minute costs a few writes. A
game that already keeps the numbers (in a profile with this week's stats, say)
writes them as they are with `boards:set(player, "combo", value, "week")`.

## On the wall

The Dance Floor's wall shows the top 5 best combos to everyone, without a
request per player. `publish` reads the board every 60 seconds and puts its
rows at `shared.boards.combo`, which each player sees at `server.boards.combo`:

```luau [src/server/Boards.luau]
local boards = Lucy.Boards.new({
    -- queue, server and boards as above
})
boards:publish("combo", { count = 5 })
return boards
```

```luau [src/client/World/ComboWall.luau]
local top = app.state:ref("server.boards.combo")

Lucy.Leaderboard.new({
    rows = function()
        return top() or {}
    end,
    loading = function()
        return top() == nil
    end,
    placeholders = 5,
    size = "lg",
    Parent = wallGui, -- a SurfaceGui on the wall's part
})
```

After a round ends, `boards:refresh()` publishes again straight away, so the
new champion goes up without waiting for the minute to pass.

## Try it in Studio

DataStores work in Studio only when the place is published and **Enable Studio
Access to API Services** is on in Game Settings. Without that, the data queue
keeps everything in memory for the session, so posting, the dialog, ranks and
the wall all still work while you build. They start empty on every Play.
