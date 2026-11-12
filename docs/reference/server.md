---
title: The server
description: Lucy.Server and app.server, every option and method, which paths reach which players, and how changes travel.
order: 4
---

# The server

`Lucy.Server` keeps the server's state in the same kind of store as the App,
sends each player the part they may see, and takes their requests. The App
mirrors it at `server.*` and sends requests through `app.server`.

```luau
-- Server
local server = Lucy.Server.new({
    state = { shared = { show = { phase = "Signup", round = 1 } } },
})

-- Client
local app = Lucy.App.new({ server = true })
local phase = app.state:ref("server.show.phase")
```

For a walkthrough, see [Share state with the server](../guide/server.md).

## Paths

Where a value sits in `server.state` decides who sees it:

| Path on the server | Who sees it | In their App at |
|---|---|---|
| `shared.*` | every player | `server.*` |
| `players.u<UserId>.*` | that player only | `server.me.*` |
| anything else | nobody: it stays on the server | |

Keys in replicated state must not contain dots. `server.*` in the App is read
only: the next update from the server replaces anything written there.

## Lucy.Server.new(options)

| Option | Default | What it does |
|---|---|---|
| `state` | `{}` | The starting tree; `shared` and `players` are added if missing |
| `namePrefix` | `"Lucy_"` | The remotes folder is `<namePrefix>Server`; give the App the same |
| `parent` | ReplicatedStorage | Where the remotes folder goes |

Make one server, early, in one server script, and share it through a
ModuleScript that returns it (see [Game folder structure](../recipes/folder-structure.md#the-server)).

## On the server

| | |
|---|---|
| `server.state` | The whole tree, with the store's methods: `get`, `set`, `update`, `merge`, `remove`, `subscribe`, `batch`, `scope` (see [The store](store.md)) |
| `server:player(player)` | That player's part (`players.u<UserId>`) as a scoped store. It exists from when they join until they leave, when it is removed |
| `server:handle(name, fn)` | Handles requests named `name`: `fn(player, ...)`. Its first return value goes back to `app.server:call`. Returns a function that stops handling. A name has one handler |
| `server:flush()` | Sends what changed now. It runs every frame by itself |
| `server:destroy()` | Stops sending and handling, and drops the remotes |

A handler that errors is printed as a warning, and the client's `call` raises
that error. Requests from a player who has left are refused.

## In the App

| | |
|---|---|
| `Lucy.App.new({ server = true })` | Mirrors the server at `server.*` and makes `app.server`. Pass `{ namePrefix = ..., parent = ... }` instead of `true` when the server uses others |
| `app.server:send(name, ...)` | A request; nothing comes back |
| `app.server:call(name, ...)` | A request that waits for the handler's answer. Raises an error if there is no handler or it failed |

The link finds the server without holding up `App.new`, so values arrive a
moment after the App starts: read them as possibly `nil` at first. Requests
sent before the link has found the server wait and go when it has.

## How it travels

Once a frame, the server compares what changed with what each player last got
and sends only the differences. Tables that did not change are skipped whole,
so a large tree costs little while it is still. A player gets everything when
their App says it is ready. Write related values in `server.state:batch` so
players never see half a change.
