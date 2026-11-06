# 0038: Tours and quiet mode

- Status: proposed
- Date: 2026-11-06

## Context

Dance Lab's first show is a tutorial: a host walks a new player through the
menu, joining, picking a song and building a routine, one arrow and one line
per step. Every game needs something like it, and doing it well touches most
of Lucy at once:

- **Pointing at UI the game already has.** The steps target real controls by
  their LucyId: a HUD button, a menu item, a button inside a song picker that
  opens later, a row inside a ScrollArea. They live in different ScreenGuis,
  under UIScales, and move (scrolling, layout, a menu sliding in).
- **Advancing when the player does the thing**, not on a NEXT button: pressing
  the target, an action key, or the app reaching a state (signed up, a routine
  has clips).
- **Holding the player on the step** with mouse, touch, keyboard and gamepad:
  presses elsewhere go nowhere, gamepad focus stays on the target. In Roblox an
  Active Frame does not stop a GuiButton behind it, so blocking needs buttons.
- **Getting out.** Focus is held on the target, so a gamepad cannot reach a
  SKIP button in the callout.
- **Quiet.** While a tutorial runs, nothing else may talk to the player:
  toasts, prompts, nags. Dance Lab would otherwise check a flag in every place
  that pops something up.
- **Voice.** The host's lines are recorded later; the game plays them. Lucy
  plays no audio (ADR 0020).

## Decision

### 1. Quiet mode: `app.quiet` (Core/Quiet)

A counted stack of reasons on every app, with channels.

```luau
local release = app.quiet:push("tour", { allow = { "tour" } })
app.quiet:active()            -- tracked: any reason pushed
app.quiet:allows("rewards")   -- tracked: not quiet, or every reason allows the channel
local cancel = app.quiet:after("rewards", fn)  -- now if allowed, else once it is
release()
```

- `push` returns a release function (idempotent) and is cleaned up with the
  current owner when there is one. Reasons may repeat; each push is counted.
- A channel is any string a game picks ("rewards", "competition"). A reason
  allows only the channels it lists; `"essential"` is always allowed.
- The app publishes `quiet.reasons` (the list, newest last) for Devtools.
- `after` is how a game holds its own prompts: the callback runs once, the
  first time the channel is allowed, unless cancelled first.

**Toasts** take `channel` (default `"default"`) and `quiet`:

- `"hold"` (the default): kept and shown when the channel is allowed again,
  newest `visibleToasts` only, each with its full duration from then. A held
  toast updated by `id` is replaced in the queue.
- `"drop"`: thrown away (for news that goes stale).
- `"show"`: shown anyway (errors, disconnects).

Dialogs, sheets and scenes do not change: a game opens its own prompts through
`app.quiet:after`.

### 2. `Lucy.Tour` (Components/Tour)

```luau
local tour = Lucy.Tour.new(app, {
	id = "first-show",
	steps = {
		{ id = "menu", target = "hud-menu", text = "Tap the menu to get started.",
		  side = "top" },                                  -- waitFor defaults to "press"
		{ id = "join", target = "menu-signup", text = "Join the show.",
		  waitFor = { state = "server.me.competition.signedUp", equals = true } },
		{ id = "fill", target = "choreo-autofill", text = "Hit auto-fill.",
		  waitFor = { state = "choreo.clips", where = function(c) return #c > 0 end } },
		{ id = "hi", text = "Hey, I'm Lucy!", waitFor = "next" },   -- no target: centred
	},
	progress = "save.tours.first-show",   -- optional: a state path the game persists
	quiet = true,                          -- the default: quiet for the run, allowing "tour"
	skippable = true,
	onStep = function(step, index) end,    -- a step is on screen: play its voice line here
	onDone = function() end,
	onSkip = function() end,
})
tour:start()          -- resumes from progress; false when progress says it finished
tour:skip()  tour:stop()  tour:advance()
tour.index()  tour.step()  tour.running()  tour.waiting()   -- tracked getters
```

**Steps.**

- `target`: a LucyId, a GuiObject, a handle, or a getter returning one. None:
  the callout is centred and the step is text only.
- `waitFor`:
  - `"press"` (the default with a target): the target, or a component inside
    it, emits `activate`, `toggle` or `select` (UiEvents gains an observer
    list, run before the `sound = false` check, so a silenced button still
    counts);
  - `"next"` (the default without one): a NEXT button in the callout;
  - `{ action = name }`: an `app.actions` action is pressed;
  - `{ state = path, equals = value }` or `{ state = path, where = fn }`;
  - `{ when = getter }`: any tracked condition.
  A condition already true when the step starts advances at once.
- `text`, `title`; `side` (`"auto"` or top, bottom, left, right; auto picks the
  side with room, as popups do); `action` (an action name whose keys show as a
  Kbd in the callout); `scrim` (default true); `pad` (the cut-out's margin, 8).

**On screen.** Everything floats in a new `tour` portal (display order 950:
above dialogs, below toasts). A step is shown only while its target is shown;
until then the tour is waiting: nothing is drawn or blocked, so a missing
target can never trap the player. Once shown:

- **The cut-out.** Four clear TextButtons around the target's rect take every
  press outside it (dimmed by the scrim rule, or clear with `scrim = false`);
  presses inside reach the target. The rect is the target's, clipped by every
  ScrollingFrame and `ClipsDescendants` above it, plus `pad`, read every frame
  and written as shares of the tour root (absolute pixels are after UIScale).
- **Scrolling.** The target is scrolled into view when the step shows
  (`Scroll.reveal`).
- **Focus.** While navigating, focus moves to the target and is put back on it
  whenever it lands outside (the gamepad's own selection included). The
  previous focus comes back when the tour ends.
- **The callout** is placed by `Overlay.place("popup", ...)` against the
  cut-out, with a notch on the near edge pointing at the target. It holds the
  title, text, the step's key hint, NEXT when the step waits for it, and SKIP
  with the back key's hint.
- **The pointer** is a `Lucy.Arrow` (its own component, so games point at
  things with it outside tours too: arrow, chevron or triangle; bounce, pulse
  or none; any token colour, or the game's own icon). It points at the cut-out
  from the side away from the callout, or from the left or right when that side
  has no room. `pointer` on the tour or a step passes Arrow props, `false` turns
  it off. Players did not see what to press with only a callout and a ring.
- **Motion.** The cut-out and callout glide to the next target (0.3 s), the
  callout fades and slides in from the target's side (0.25 s, a cover over it
  fades: CanvasGroups blur text), a ring ripples out from the target, the arrow
  grows in with an overshoot and bounces. Reduced motion: jump between targets,
  fade only, no ripple, a still arrow that fades in.
- `onStep(step, index)` runs when the step is first shown, never while
  waiting; the game plays its line there and decides what to do when a line
  has no recording yet. Lucy never waits on audio.

**Skipping asks first, in place.** SKIP and back (B, Backspace) both ask in the
callout with `Lucy.InlineConfirm`: the step's words step aside for "Are you
sure?" with YES and NO (NO focused). YES skips; NO, or back again, puts the step
back. A new step puts the question away. A tour with `skippable = false`
swallows back. Text is overridable (`text = { next, skip, confirm, yes, no }`).

**Progress.** With `progress`, the tour writes `{ step = index }` there as it
goes and `{ finished = "done" | "skipped" }` at the end; `start()` resumes at
the saved step, and returns false for a finished tour (`start(1)` replays).
Saving it is the game's job.

**State.** The app publishes `tour = { id, step, index, waiting }` for the
running tour, nil otherwise. One tour runs at a time; starting a second stops
the first.

## Consequences

- A game writes a tutorial as data over the LucyIds it already has, and it
  works with every input Lucy supports.
- Nothing about the rest of the UI changes while a tour runs; it can only be
  blocked from the tour layer, and only while a target is shown.
- Every game gets quiet mode for free in toasts; its own prompts need one
  `after` call each.
- UiEvents grows an observer list; `activate`, `toggle` and `select` become
  something code can rely on, not only sounds.
- Per frame cost while a step shows: one rect read and four writes.
- Watch: targets inside other modal overlays (the cut-out sits above them, so
  presses pass straight through to the target); a target that is re-created
  under the same LucyId (resolved again every frame by id).

## Alternatives considered

- **A Dialog or Sheet per step.** Rejected: they cannot point at a control or
  let presses reach it.
- **A highlight that copies the target above a scrim.** Rejected: a copy does
  not run the real control's behaviour.
- **One full-screen scrim and a hole by `ClipsDescendants`.** Roblox has no
  hole masks; four rectangles are the simplest shape that blocks correctly.
- **Quiet as a flag every caller checks.** Rejected: it is what the game does
  today, and it is forgotten in new code. Toasts handle it themselves; prompts
  get `after`.
- **Back skips at once, or a held B.** The user picked a confirm: one stray
  press does not throw a new player out of the tutorial.
- **A "Skip the tour?" Dialog** (the first version), and SKIP skipping at once.
  Replaced: with SKIP the only button in the callout, players pressed it without
  reading; a dialog over the tour hid what it was asking about. The question now
  sits where SKIP was pressed, and both ways in ask.
