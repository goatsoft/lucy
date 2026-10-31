---
title: Share state with the server
description: Keep server state in Lucy's store on the server, see it in every App at server.*, and send requests back with checks.
order: 12
---

# Share state with the server

The server owns what matters: the round, the scores, who signed up, each
player's coins. `Lucy.Server` keeps that in the same kind of store your App
has, sends players what they may see, and takes their requests. Your UI binds
to it like any other app state, with no attributes or remotes to wire up.

## On the server

Make one server, early, in a server script:

```luau
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local server = Lucy.Server.new({
    state = { shared = { show = { phase = "Signup", round = 1 } } },
})
```

`server.state` has the store's methods: `get`, `set`, `update`, `merge`,
`remove`, `subscribe` and `batch` (see [The store](../reference/store.md)).
Where you put a value decides who sees it:

| Path | Who sees it | In their App at |
|---|---|---|
| `shared.*` | every player | `server.*` |
| `players.u<UserId>.*` | that player only | `server.me.*` |
| anything else | nobody: it stays on the server | |

```luau
server.state:set("shared.show.phase", "Live")      -- everyone
server:player(player):set("coins", 50)             -- this player
server.state:set("rounds.seed", 1234)              -- the server only
```

`server:player(player)` is that player's part as a store of its own. It exists
from when they join until they leave. Keys in replicated state must not
contain dots.

## In the App

Ask for the link when you make the App:

```luau
local app = Lucy.App.new({ server = true })

local phase = app.state:ref("server.show.phase")
local coins = app.state:ref("server.me.coins")

Lucy.Text.new({
    text = function()
        return `{phase()} · {coins() or 0} coins`
    end,
    Parent = scene.gui,
})
```

The values arrive a moment after the App starts, so read them as possibly
`nil` at first. Treat `server.*` as read only: the next update from the server
replaces anything you write there. Keep your own UI state elsewhere.

## Requests

Players ask the server to do things with requests. Handle each one by name, and
check everything that arrives: a client can send anything.

```luau
-- Server
server:handle("buy", function(player, itemId)
    local item = ITEMS[itemId]
    if type(itemId) ~= "string" or not item then
        return false
    end
    local me = server:player(player)
    if (me:get("coins") or 0) < item.price then
        return false
    end
    me:update("coins", function(coins)
        return coins - item.price
    end)
    return true
end)
```

```luau
-- Client
app.server:send("vote", "House")                  -- nothing comes back
local bought = app.server:call("buy", "moonwalk") -- waits for the answer
```

`call` returns what the handler returned, and raises an error if there is no
handler or it failed. Requests sent before the link has found the server wait
and go when it has. Requests from a player who has left are refused.

## How it travels

Once a frame, the server compares what changed with what each player last got
and sends only the differences. Tables that did not change are skipped whole,
so a large tree costs little while it is still. A player gets everything when
their App says it is ready. Write related values in `server.state:batch` so
players never see half a change.

| Option | Default | What it does |
|---|---|---|
| `state` | `{}` | The starting tree; `shared` and `players` are added if missing |
| `namePrefix` | `"Lucy_"` | The remotes folder is `<namePrefix>Server` in ReplicatedStorage; pass the same to the App's `server` option |
| `parent` | ReplicatedStorage | Where the remotes folder goes |

The App's `server` option is `true`, or a table with `namePrefix` and
`parent` when the server uses others.

## Next

- [Work with app state](app-state.md)
- [UI in the world](world-ui.md): boards and name tags drawn from server state
