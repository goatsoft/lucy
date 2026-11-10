# 0043: Boards on the server and useRequest on the client

- Status: accepted (JB, 2026-11-10)
- Date: 2026-11-10

## Context

The data queue (ADR 0035) made writing and reading OrderedDataStores safe, and the
Leaderboard component draws a board. Between the two, every game still writes the
same few hundred lines. Dance Lab's LeaderboardService shows them:

- A weekly board is the same store under a scope named for the week, and the week
  has to be worked out the same way every time (Monday 00:00 UTC).
- An OrderedDataStore cannot say where one key ranks, so a player's own rank comes
  from reading the top N and looking for them, and past N they are "100+".
- Rows need names, which means a cached `GetNameFromUserIdAsync` with the players
  in the server known first.
- The client asks with a request the server has to check, and walls want the top
  rows published to everyone rather than asked for by each player.

On the client, the panel and the docs example both hand-roll the same thing: a ref
for the answer, `task.spawn(app.server:call(...))`, a counter so a late answer to an
old tab is dropped, and `loading = answer() == nil`. A shop's stock or a friend's
profile needs exactly the same.

## Decision

Two additions, both small, each useful without the other.

`Lucy.Boards` (Core/Boards) is a server module on top of a game's DataQueue. A
game lists its boards (`store`, `kind` = best or total, `periods` = all, week,
day) and gets `post`, `set`, `get`, `top`, `publish` and `refresh`. With a
`Lucy.Server` it handles the `boards.get` request, checking the board and period
against the list and passing the asking player so `me` is theirs. Week and day
are scopes `w<week>` and `d<day>` on the same store: nothing resets, a new period
simply starts empty. Rows are `{ userId, name, value, rank }`, the shape the
Leaderboard component takes.

`Lucy.useRequest(app, name, args, options)` is a composable: `data`, `loading`,
`error`, `refresh`. `args` is a getter read reactively, so a new tab asks again;
only the newest call's answer lands. `enabled` holds calls while a panel is
closed, `every` polls, `keep` keeps the old answer while the new one loads.

Which boards a game has, their formats, medals and tabs stay in the game.

## Consequences

- A leaderboard is three short pieces, which the Leaderboards recipe shows
  together: the boards on the server, useRequest, and the component.
- The board names are request arguments, so `Boards` refuses anything not on
  its list; games no longer write that check.
- Store names and scopes match what Dance Lab already writes (`w<week>` with the
  same week count), so it moves over with no data migration.
- Ranks past `depth` are not known. Raising it costs a bigger sorted read; the
  queue still reads each page at most once a `ttl`.

## Alternatives considered

- A leaderboard composable that calls DataStores itself: composables run on the
  client, and DataStores are server only.
- Folding board rules into DataQueue: the queue is about pacing any DataStore
  traffic, and periods, ranks and names are leaderboard rules.
- Publishing every board for every player instead of a request: the top 20 of
  every board and period for every player is far more replication than one
  answer when a dialog opens.
