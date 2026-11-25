# 0058: Checked requests, two channels, profiles and services

- Status: accepted (JB, 2026-11-25)
- Date: 2026-11-25
- Amends: 0033 (the server), 0035 (the data queue)

## Context

Two games built on Lucy (Dance Lab, Crime Spree) were compared with the way the
biggest Roblox games are built. Four gaps were in Lucy itself:

1. **Requests were trusted.** `server:handle` passed whatever a client sent to
   the handler, as often as it was sent. Each handler had to check its own
   arguments and none limited how often a player could ask. A 100 player
   shooter's `fire` request is the first thing an exploiter floods.
2. **One channel.** Everything went over a RemoteEvent and a RemoteFunction,
   both reliable. Aim, shots and positions, which the next message replaces,
   paid for ordering and resends they do not need.
3. **Syncing cost grew with players.** Each flush compared the shared tree once
   per player, every frame: 100 comparisons of the same tree at 100 players.
4. **No session lock.** The data queue paced writes but a player's data could be
   loaded by a second server before the first had saved it. In a game with
   trading that is the classic item dupe. Dance Lab wrote a lock of its own; it
   reads the lock rather than claiming it, and loads anyway after a few tries.
5. Each game started its services from a hand ordered list.

The networking libraries the top games use (Blink, Zap, Lync, BlinkBlox) all
check every payload against a schema and rate limit each event per player;
ProfileStore (and ProfileService before it) is the usual answer to dupes.

## Decision

- **`Lucy.Check`**: checks are functions answering `true` or `false, why`.
  `server:handle(name, fn, { check, rate, unreliable })` runs the argument
  checks (more arguments than checks fail) and a token bucket per player per
  request before the handler. `Server.new({ strict = true })` makes `check`
  required. Every dropped request goes to `onReject`. A failing handler's error
  stays on the server; the client hears only that it failed.
- **An unreliable channel**: an UnreliableRemoteEvent `Stream` beside `Sync` and
  `Call`. `server:stream(player?, name, ...)` and `app.server:onStream` from
  the server; `app.server:stream` and `handle(..., { unreliable = true })`
  from the client. A handler belongs to one channel.
- **One shared comparison per flush**, reused for every player that had the
  last one; a player who became ready since gets their own. `flushRate` lets a
  busy server send at 20 a second instead of every frame.
- **`Lucy.Profiles`** on the data queue: `load` claims the key with UpdateAsync
  (this server's JobId and the time), waiting `tries x wait` for another
  server's fresh claim and then answering `nil, "in use"`, never loading the
  data anyway. A claim older than `stale` is a dead server's and is taken over.
  Every save is an update that checks the claim is still ours; if not, the
  profile is lost, never written again, and `onLost` fires. `receipt` grants a
  purchase once per PurchaseId and answers once saved. `commit` saves several
  profiles and waits for all (trades).
- **`Lucy.Services`**: services name what they `need`; `run` orders them,
  refuses a loop or a missing need, runs every `init` (which must not yield)
  and then every `start` on its own thread, isolating a failing start.

## Changed in review (PR #5)

The review of PR #5 made these part of the decision:

- **Grants never yield.** `receipt` runs `grant` on a copy of the data; one that
  yields is closed and one that errors is dropped, changing nothing. On success
  its changes and the PurchaseId go into the profile in one step with no yield
  between, so no save holds one without the other. This also removes any
  release held back by a grant, so `close` (what BindToClose runs) is just
  release everything and flush.
- **A save writes only under this server's own claim**; a missing claim (taken
  over and let go) marks the profile lost too. Only `load` takes over a claim.
- **Loads:** one in flight load per key; a load waits for this server's own
  release of the key, writes it again if it gave up, and claims afresh past a
  lost copy's write that gave up. A receipt whose save gave up is saved again on
  Roblox's retry. `commit` checks every profile before saving any.
- **Studio claims** use an id made once per session, not a shared `"studio"`.
- **Ready:** a ready from a player who left is ignored; repeated readies get
  everything again at most once at once and then once every ten seconds.
- **Checks:** vectors must be finite with or without `max`; lists must have
  keys exactly 1..n and stop at their limit; a rate under one a second keeps a
  burst of at least one. `Boards` registers `boards.get` with checks and a rate
  so it works on a strict server.
- **ServerLink** attaches `Stream` whenever it replicates. **Services** closes
  an init that yielded before raising.

## Consequences

- Old handlers keep working: without `check` nothing is checked, but they get
  the default rate (30 a second). Games should turn on `strict`.
- The client's `call` error no longer carries the server's message.
- Profiles cannot make two DataStore keys change together; `commit` keeps the
  gap short and both profiles held, which is what ProfileStore does too.
- Not done here: buffer serialisation for the unreliable channel (a game that
  streams a lot can pack its own buffers), and a MessagingService nudge so a
  server lets go of a profile the moment another asks.
