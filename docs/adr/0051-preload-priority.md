# 0051: Pictures load by priority: pinned, anticipated, or when shown

- Status: accepted
- Date: 2026-11-18
- Amends: 0049 (its last consequence: rarely opened panels preloaded on hover or focus, which was
  never built), the Grid's `preload` (every item at once)

## Context

ADR 0050 builds every dialog, sheet, menu and select on its first open. Its frames now cost nothing
until they are needed, but its pictures start loading when the panel first shows. Dance Lab already
preloads its store renders, dance icons and Club Pass pictures on the entering screen
(`Lucy.preload`), and on a fresh start The Lab still opened with its icons missing for about a
second, then late pictures again later in a session (Dance Lab, Studio, 2026-11-18):

1. **Lucy's icons are never preloaded.** The trophy, lightning, star, lock, close cross and the
   Robux and VIP marks are cells of one icon sheet (Dance Lab's: 1024 px, 69 icons). Nothing loads
   it before the first panel that draws an icon.
2. **A preloaded picture can be dropped again.** `Lucy.preload` draws each picture once, tiny, and
   removes the copy once it has loaded. Roblox loads a picture when something visible uses it, and
   can unload it under memory pressure once nothing does (as DevForum reports describe). So a
   picture warmed at the start can be gone again by the time its panel opens, minutes later.

Roblox gives a game no way to unload a picture itself. What a game controls is which pictures stay
in use (Roblox keeps them) and which are only warmed shortly before they are needed (Roblox may drop
them when they are not). Memory is spent by the first kind; frame-perfect panels need the second to
happen early enough.

The virtual Grid has the opposite problem: with `preload` it fetches every item's pictures as the
list arrives. That is right for The Lab's hundred dance icons and wrong for a list that keeps
growing (a feed, a catalogue, an inventory of thousands), where it loads pictures no one scrolls
to and keeps nothing near the view first.

## Decision

Every picture Lucy loads ahead has one of three priorities.

### 1. Pinned: loaded at launch and kept

`Lucy.preload(ids, { pin = true })` loads the pictures and keeps their drawn copy (2 by 2 pixels,
nearly see-through, in the `LucyPreload` gui under everything) for as long as the game runs, so
Roblox never counts them unused. The job has `release()`, which removes the copies and lets Roblox
drop them again. A picture pinned twice is kept until both release it.

**Icon sheets are pinned by Lucy.** Every image an `Icon.register` names (Lucy's own sheet and the
game's from `lucy-icons build`) is pinned on a client when it is registered: one sheet holds every
icon, so one pin covers them all. `Icon.pin = false` turns it off.

What else to pin is the game's choice, made once at launch: what the first screens show and what
every player opens. Pins are counted (section 4), so the cost stays visible.

### 2. Anticipated: warmed just before they are needed

Warming is what `Lucy.preload` does today: load, draw once, let go. A warmed picture counts as
loaded for `Preload.fresh` seconds (120); asked for after that, it is drawn again, since Roblox may
have dropped it. Lucy warms ahead of the player in two places.

**Lists.** A virtual Grid with `preload` warms a window, not the whole list: the items in view,
then `Grid.preloadAhead` screens (default 2) in the direction the player last scrolled and
`Grid.preloadBehind` (default 1) the other way, nearest first, again as the view moves. Items far
behind are not held. A list short enough to fit in that window is warmed whole, as before.

**Overlays.** A Dialog, Sheet, Menu or Select takes `preload`: a list of pictures, or a function
returning one, called when it is needed. `overlay:warm()` warms them and builds the presence ahead
(0050), one overlay a frame as `Lucy.prebuild` does. Lucy calls `warm()`:

- when anything in its `trigger` (a button, its handle, or a list of them: what opens it) is
  hovered, focused or selected on a gamepad: the half second before a press;
- when an overlay that names it in `ahead` opens: The Lab opening warms its dance and pack sheets;
- and on open, its pictures go to the front of the queue (`first`).

A trigger only warms; it does not open anything. Without `trigger` or `ahead` nothing changes.

### 3. On demand

Everything else loads when it is first shown, and Roblox may drop it when it is not.

### 4. Measured

`Lucy.Preload.stats()` returns how many pictures are pinned, warmed and waiting. `Devtools.memory()`
adds Roblox's own memory figures for textures, gui and Lua (`Stats:GetMemoryUsageMbForTag`), and
the MCP's `memory` tool returns both. A change to what is pinned is checked against those numbers.

## Order of work

1. **Core**: `pin` and `release()` in Preload, `stats()`; Icon pins registered sheets.
2. **Grid**: the preload window.
3. **Overlays**: `preload`, `warm()`, `trigger`, `ahead` on Dialog, Sheet, Menu and Select.
4. **Devtools and MCP**: `memory`.
5. **Dance Lab**: pins its HUD pictures and the Club Pass tiers near the player's tier; The Lab, the
   dance menu and the inventory take `preload` and `trigger` (their pictures are warmed when their
   buttons are hovered or focused, not kept); The Lab names its dance and pack sheets in `ahead`.
   Measured before and after: texture memory in the club, and first opens on a fresh start and
   after a long session.

### Measured in Dance Lab

Lucy d7e6163, Dance Lab c7ced4c, Studio Play, desktop, 2026-11-18:

- **What is pinned:** 14 pictures in the club: the icon sheet, the Club Pass showcase tiers (the
  intro pass and The Lab overview) and the cards of the player's tier and the next six
  (`RewardTile.pinNear`, moved on as the tier changes).
- **First opens:** before, on a fresh start The Lab drew its icons about a second late, and late
  renders came back later in a session. After, on a fresh start and again after 141 s idle in the
  club (past `Preload.fresh`), The Lab opened complete on its first frame, by its hotkey path
  (nothing warmed ahead). The intro Club Pass drew its showcase cards on its first frame.
- **Anticipation:** focusing MENU built the club menu (141 instances); opening it built the dance
  menu (503) and the inventory (271), both still closed, and warmed the store pictures.
- **Memory:** about 214 MB of textures in the club in Studio. No figure was taken before the
  change, and Studio's are not a phone's: to be measured on a device.
- **Not anticipated:** a hotkey (B for The Lab, I, N) has nothing to hover. Those panels build on
  open as 0050 has them, with their pictures warmed on the entering screen and whenever the club
  menu opens; a fresh start through a hotkey still showed every picture at once.

## Consequences

- An icon never pops in. One sheet's texture (about 4 MB for 1024 px) stays in memory for the
  game's life.
- A game decides what stays in memory by what it pins; everything else Roblox may reclaim.
- A long list loads what the player is about to see, not everything, and its memory follows the
  view.
- A panel's pictures are warming from the moment its button is hovered or focused; on touch, where
  nothing hovers, from when the panel underneath opens or the game prebuilds it.

## Alternatives considered

- **Pin everything a game might show.** Simple, and no picture ever pops in, but memory grows with
  the catalogue and Roblox can no longer reclaim it on a small phone.
- **Warm everything at launch and hope.** What Dance Lab did. It works for a while, then Roblox
  drops what is unused.
- **Keep every closed panel built and hidden.** 0050 removed that cost on purpose, and whether a
  hidden frame keeps its pictures in use is not something Roblox promises.
