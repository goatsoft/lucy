---
title: Tour
description: A guided walk through your game's own UI, one step at a time.
---

# Tour

A tour points at the buttons your game already has, one at a time, and waits
for the player to use each one. Use it for a first-time tutorial, or to show
off a new screen. It works with mouse, touch, keyboard and gamepad, and keeps
the rest of the app quiet while it runs.

```luau
local tour = Lucy.Tour.new(app, {
    id = "first-round",
    steps = {
        { id = "hi", title = "Welcome!", text = "Here is a quick look around." },
        { id = "play", target = "play", text = "Press Play to start a round." },
        { id = "shop", target = "shop", text = "The shop sells new looks.", side = "top" },
    },
    onDone = function() print("finished") end,
})
tour:start()
```

`target` is the id you gave a component (`Lucy.Button.new({ id = "play" })`).
[Write a tutorial](../guide/tutorials.md) walks through a whole one.

## What the player sees

While a step's target is on screen:

- the screen dims, but for a cut-out round the target, with a ring on it;
- presses outside the cut-out do nothing, presses on the target work as usual;
- a callout next to the target holds the step's title and text, with an arrow
  pointing at it;
- on a gamepad or keyboard, focus moves to the target and stays there.

Until the target is on screen (a menu that has not opened yet), the tour waits
and draws nothing, so the player can never get stuck behind it.

The back keys (B, Backspace) ask "Skip the tour?", with KEEP GOING picked
first. The callout's SKIP button does the same without asking.

## Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `id` | string | | Names the tour (required) |
| `steps` | table | | The steps, in order (below) |
| `progress` | string | | A state path the tour writes its progress to, so a rejoin carries on (see Progress) |
| `quiet` | boolean | `true` | Keeps the app quiet while it runs: toasts wait until it ends (see [Write a tutorial](../guide/tutorials.md#quiet-mode)) |
| `skippable` | boolean | `true` | `false` hides SKIP and makes back do nothing while a step shows |
| `text` | table | | Your own words for `next`, `skip`, `confirm` and `keepGoing` |
| `onStep` | function | | `(step, index)`, the first time each step is on screen. Play a voice line here |
| `onDone` | function | | The player finished the last step |
| `onSkip` | function | | The player skipped |

## Steps

| Field | What it does |
|---|---|
| `id` | Names the step, for `onStep` and `tour.step()` |
| `title`, `text` | What the callout says (at least one) |
| `target` | The component id to point at. Also a GuiObject, a component, or a function that returns one. Leave it out for a step that only talks: its callout sits in the middle with a NEXT button |
| `waitFor` | What moves the tour on (below) |
| `side` | `auto` (the default), `top`, `bottom`, `left` or `right`: where the callout sits. It moves to the other side when there is no room |
| `action` | An action name (see [Hotkeys](../guide/actions.md)) whose key shows in the callout |
| `scrim` | `false`: no dimming. Presses outside the target are still blocked |
| `pad` | Room between the target and the cut-out's edge, in pixels (`8`) |

`waitFor` is one of:

| Value | Moves on when |
|---|---|
| `"press"` | The player presses the target, or something inside it. The default when there is a target |
| `"next"` | The player presses NEXT. The default when there is no target |
| `{ action = "dance" }` | The player presses the action's key |
| `{ state = "me.coins", equals = 100 }` | A state key has that value |
| `{ state = "me.clips", where = function(clips) return #clips > 0 end }` | A state key passes your test |
| `{ when = function() return ... end }` | Anything your function reads says so |

A step whose condition is already true moves on at once.

## Methods

| Method | What it does |
|---|---|
| `tour:start(step?)` | Starts it, from the saved step with `progress`. Returns `false` for a tour already finished; `tour:start(1)` replays it |
| `tour:advance()` | Moves to the next step yourself |
| `tour:skip()` | Ends it as skipped (`onSkip` runs) |
| `tour:stop()` | Ends it without a callback, keeping its progress |
| `tour:destroy()` | Stops it and removes what it made |
| `tour.index()`, `tour.step()` | The step it is on |
| `tour.running()`, `tour.waiting()`, `tour.confirming()` | Whether it runs, waits for a target, or is asking to skip |

The getters are tracked: code that reads them runs again when they change.
One tour runs at a time: starting another stops the first. While one runs the
app publishes `tour = { id, step, index, waiting }`.

## Progress

With `progress = "save.tours.firstRound"`, the tour writes `{ step = 2 }`
there as the player goes, then `{ finished = "done" }` or
`{ finished = "skipped" }`. Save that path with the rest of the player's
data; next time, `tour:start()` carries on from the step, or returns `false`
when it is finished.

## Voice and sound

Lucy plays no audio. Play a step's line in `onStep`, which runs once, when the
step is first on screen. Show the same words as `text` so players with the
sound off get them too.

```luau
onStep = function(step)
    local sound = voiceLines[step.id] -- nil until it is recorded
    if sound then
        sound:Play()
    end
end,
```

## Look

Rules on the tags `ui-tour-scrim`, `ui-tour-ring`, `ui-tour-callout`,
`ui-tour-arrow`, `ui-tour-title` and `ui-tour-text`, with the theme's
`Overlay`, `Ring`, `Popover`, `PopoverForeground` and `Border` colours. The
tour floats above dialogs and below toasts.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Tour")`.
