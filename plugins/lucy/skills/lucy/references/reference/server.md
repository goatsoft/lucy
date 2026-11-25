<!-- Made by scripts/skills.ts from docs/reference/server.md. Edit the doc, not this file. -->
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
| `strict` | `false` | `true`: `handle` raises unless it is given a `check` (`{}` for a request with no arguments), so no request reaches a handler unchecked. Use it in games |
| `rate` | `{ perSecond = 30, burst = 30 }` | How often one player may make a request whose handler gives no `rate` |
| `flushRate` | `0` | Seconds between sends. `0` sends every frame; `0.05` (20 a second) suits a busy server |
| `onReject` | none | `fn(player, name, why)` when a request is dropped: too many, bad arguments, no handler. Log it, or kick a player who keeps at it |

Make one server, early, in one server script, and share it through a
ModuleScript that returns it (see [Game folder structure](../recipes/folder-structure.md#the-server)).

## On the server

| | |
|---|---|
| `server.state` | The whole tree, with the store's methods: `get`, `set`, `update`, `merge`, `remove`, `subscribe`, `batch`, `scope` (see [The store](store.md)) |
| `server:player(player)` | That player's part (`players.u<UserId>`) as a scoped store. It exists from when they join until they leave, when it is removed |
| `server:handle(name, fn, options?)` | Handles requests named `name`: `fn(player, ...)`. Its first return value goes back to `app.server:call`. Returns a function that stops handling. A name has one handler. Options below |
| `server:stream(player?, name, ...)` | Sends `name` on the unreliable channel to one player, or to every ready player when `player` is `nil`. The App hears it with `app.server:onStream` |
| `server:flush()` | Sends what changed now. It runs every frame (or every `flushRate` seconds) by itself |
| `server:destroy()` | Stops sending and handling, and drops the remotes |

A handler that errors is printed as a warning, and the client's `call` raises
an error that does not say why (the reason stays on the server). Requests from
a player who has left are refused.

### Handle options

| Option | What it does |
|---|---|
| `check` | A list of checks, one for each argument, from `Lucy.Check`. The handler runs only when every one passes, and more arguments than checks fail, so a handler can trust what it is given |
| `rate` | `{ perSecond, burst? }`: a bucket of `burst` requests per player that refills at `perSecond`. One over and the request is dropped |
| `unreliable` | `true` takes the request on the unreliable channel (`app.server:stream`) instead |

```luau
local Check = Lucy.Check

server:handle("fire", fire, {
    check = { Check.string({ max = 24 }), Check.vector({ max = 4096 }) },
    rate = { perSecond = 12, burst = 6 },
})
```

### Checks

| | Passes |
|---|---|
| `Check.any` | anything but `nil` |
| `Check.boolean` | `true` or `false` |
| `Check.string({ min?, max? })` | a string of `min` to `max` bytes (`max` is 200 when not given) |
| `Check.number({ min?, max?, integer? })` | a number in range, never NaN or infinite |
| `Check.vector({ max? })` | a Vector3 no longer than `max` |
| `Check.instance(className?)` | an Instance that is a `className` |
| `Check.oneOf({ ... })` | one of these values |
| `Check.optional(check)` | `nil`, or what `check` passes |
| `Check.array(check, max?)` | a list with no holes, of at most `max` (100) items that pass `check` |
| `Check.map(keyCheck, valueCheck, max?)` | a table of at most `max` (100) pairs |
| `Check.struct({ field = check })` | a table with exactly these fields |

A check is a function that answers `true`, or `false` and why, so a game can
write its own.

### Two channels

Requests and state go on the reliable channel: each arrives once and in order.
Aim, effects and positions, anything the next message replaces, go on the
unreliable one (an UnreliableRemoteEvent): a message may be dropped or arrive
out of order, and each must stay under about 900 bytes. A handler takes
requests from one channel only.

## In the App

| | |
|---|---|
| `Lucy.App.new({ server = true })` | Mirrors the server at `server.*` and makes `app.server`. Pass `{ namePrefix = ..., parent = ... }` instead of `true` when the server uses others |
| `app.server:send(name, ...)` | A request; nothing comes back |
| `app.server:call(name, ...)` | A request that waits for the handler's answer. Raises an error if there is no handler or it failed |
| `app.server:stream(name, ...)` | A request on the unreliable channel, for a handler with `unreliable = true`. Dropped while the link is still connecting |
| `app.server:onStream(name, fn)` | Calls `fn(...)` when the server streams `name`. Returns a function that stops it |

The link finds the server without holding up `App.new`, so values arrive a
moment after the App starts: read them as possibly `nil` at first. Requests
sent before the link has found the server wait and go when it has.

## How it travels

Once a frame (or every `flushRate` seconds), the server compares what changed
with what was last sent and sends only the differences. `shared` is compared
once for everyone; a player's own part only when it changed. Tables that did not change are skipped whole,
so a large tree costs little while it is still. A player gets everything when
their App says it is ready. A player who has left is never added back by a late
ready, and a ready player gets everything again at most once at once and then
once every ten seconds, so a client sending ready in a loop cannot make the
server send the whole state each time (dropped readies go to `onReject` as
`"ready"`). Write related values in `server.state:batch` so players never see
half a change.

## Starting a game's services

`Lucy.Services` starts a game's modules in the order they need each other. Each
service says what it `needs`; `run` inits every one in that order, then starts
them, each on its own thread. A missing need or two services that need each
other stop the game at once, naming them.

```luau
-- Services/Wallet.luau
local Wallet = { needs = { "Profiles" } }

function Wallet.init(services) -- set up; must not yield
end

function Wallet.start(services) -- may yield (loops, waits)
end

return Wallet
```

```luau
-- init.server.luau
local services = Lucy.Services.new()
services:addFolder(script.Services) -- every module there that has init, start or needs
services:run()
```

| | |
|---|---|
| `services:add(service, name?)` | Adds one; its `name` is the module's when added from a folder |
| `services:addFolder(folder)` | Requires every ModuleScript in the folder and adds the services |
| `services:get(name)` | A service by name |
| `services:order()` | The names in the order they start |
| `services:run()` | Inits in order (an init that errors or yields stops the game), then starts. A start that errors is warned about and the rest carry on |
