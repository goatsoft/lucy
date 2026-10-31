# 0033: A server half: the same store on the server, replicated to Apps

- Status: accepted (JB, 2026-11-01)
- Date: 2026-11-01

## Context

Lucy has been client only. Its docs tell games to copy server data into app
state themselves: the HUD recipe copies player attributes, the settings recipe
fetches through a RemoteFunction and saves through a RemoteEvent. The Dance Lab
rebuild (ADR 0021) shows what that costs: its server keeps show state in player
and workspace attributes and a dozen remotes, and every screen rebuilds the
same glue. World UI (ADR 0032) draws on the client, so everything a board
shows has to come down too.

The store (`Core/AppState`) is plain Luau over `Core/Reactive`: no instances,
no UI. It runs on the server unchanged. Its reads hand out frozen copies that
share every table that did not change, which makes a diff between two reads
cheap.

JB's direction: Lucy is a framework, not only a UI library; the server should
keep its state the same way the client does.

## Decision

- **`Lucy.Server.new(options)`** on the server holds a store, `server.state`,
  with the App store's methods. What replicates is decided by where it lives:
  - `shared.*` goes to every player.
  - `players.u<UserId>.*` goes to that player only. `server:player(player)`
    is that part as a scoped store. The `u` keeps the key from being an array
    index. It is made when the player joins and removed when they leave.
  - Anything else stays on the server.
- **Replication.** Once a frame, for each ready player, the server diffs what
  it last sent against the store's current copy and sends only the changes:
  `{ shared = ops, me = ops }`, each op `{ path, value }` to set or `{ path }` to
  remove (a remote cuts an array at its first nil). Unchanged branches are the
  same table in both copies and cost one comparison. A player gets everything
  when their App says it is ready, so nothing is lost to join order.
- **The client.** `Lucy.App.new({ server = true })` makes `app.server`: it finds
  the remotes without holding up `App.new`, says it is ready, and writes what
  arrives into `app.state` at `server.*`, with the player's own part at
  `server.me.*`. UI binds to it like any other state. `server.*` is read only
  by convention: the next update replaces local writes.
- **Requests.** `server:handle(name, fn)` takes requests; `fn(player, ...)`
  must check every argument. `app.server:send(name, ...)` sends one;
  `app.server:call(name, ...)` waits for the handler's answer and raises its
  error. Requests from a player who has left are refused.
- **Transport.** One folder, `<namePrefix>Server` in ReplicatedStorage, with a
  RemoteEvent (`Sync`) and a RemoteFunction (`Call`). Specs inject a transport.
- Keys in replicated state must not contain dots.

## Consequences

- Games keep server state in one tree, with the same API on both sides, and
  stop writing attribute and remote glue for UI.
- The diff costs a walk of what changed per ready player per frame. A game
  with a large, fast-changing shared tree should batch its writes.
- Rate limiting requests is the game's job for now.
- Docs: a "Share state with the server" guide; `app.md` lists the option and
  `app.server`.

## Alternatives considered

- **Attributes on instances.** Rejected: no tables, no batching, and a second
  API beside the store.
- **Replicating the whole store.** Rejected: the server holds things players
  must not see.
- **Sending whole subtrees on change.** Rejected: one changed key would resend
  everything around it.
- **A third-party replication library.** Rejected: Lucy has no runtime
  dependencies, and the store's shared copies already make diffs cheap.
