---
title: Write a tutorial
description: Walk a new player through your game's own menus with Lucy.Tour, and keep everything else quiet while you do.
order: 6
---

# Write a tutorial

A good new player tutorial points at the real buttons and waits for the player
to press them, one at a time. `Lucy.Tour` does that over the UI you already
have, so a tutorial is a list of steps, not a second copy of your menus.

## Give the buttons ids

A step points at a component by its id:

```luau
Lucy.Button.new({ id = "hud-menu", text = "MENU", onClick = openMenu })
Lucy.Button.new({ id = "menu-join", text = "JOIN THE SHOW", onClick = join })
```

Ids are unique in an app. A component inside a menu that has not opened yet is
fine: the tour waits for it.

## Write the steps

```luau
local tour = Lucy.Tour.new(app, {
    id = "first-show",
    progress = "save.tours.firstShow",
    steps = {
        { id = "welcome", title = "Welcome to the club!", text = "Wanna hit the stage tonight?" },
        { id = "menu", target = "hud-menu", text = "Tap the menu to get started.", side = "top" },
        {
            id = "join",
            target = "menu-join",
            text = "Join the show. That's your ticket to the stage.",
            waitFor = { state = "me.signedUp", equals = true },
        },
        {
            id = "fill",
            target = "auto-fill",
            text = "Short on ideas? Hit auto-fill.",
            waitFor = { state = "routine.clips", where = function(clips) return #clips > 0 end },
        },
    },
    onDone = function()
        app.toast.success("You're ready!", { channel = "tour" })
    end,
})
tour:start()
```

- A step with a `target` moves on when the player presses it. Use `waitFor`
  when the thing that matters is a result, not a press (signed up, a routine
  has clips): the player may get there another way.
- A step without a target is a message in the middle of the screen with a NEXT
  button.
- `side` puts the callout above, below or beside the target; it moves when
  there is no room.

Every option is on the [Tour](../components/tour.md) page.

## Let the player out

SKIP in the callout and back (B on a gamepad, Backspace) ask "Are you sure?"
in the callout, with YES and NO; YES skips. Let players replay it later, from a settings screen or a
kiosk:

```luau
tour:start(1)
```

## Carry on after a rejoin

With `progress`, the tour writes where the player is to that state path. Save
it with the rest of their data, and put it back before you call `start`:

```luau
app.state:set("save.tours.firstShow", saved.tours.firstShow)
if not tour:start() then
    -- finished or skipped before: nothing to do
end
```

## Voice lines

Lucy plays no audio. Play each step's line in `onStep`, which runs the first
time the step is on screen. Keep the same words in `text`, so the tutorial
works before the lines are recorded and for players with the sound off:

```luau
onStep = function(step)
    local id = voiceIds[step.id] -- nil until recorded
    if id then
        playVoice(id)
    end
end,
```

The next step waits for the player, never for the line, so keep lines short.

## Quiet mode

While a tour runs, the app is quiet: nothing else should talk to the player.
`app.quiet` keeps track of why it is quiet, and you can make it quiet yourself
for a cutscene:

```luau
local release = app.quiet:push("cutscene")
-- ...
release()
```

| Call | What it does |
|---|---|
| `app.quiet:push(reason, { allow = { ... } }?)` | Goes quiet until the returned function is called (or the code that called it is cleaned up). `allow` lists channels that may still talk |
| `app.quiet:active()` | True while any reason is pushed |
| `app.quiet:allows(channel)` | True when nothing is quiet, or every reason allows the channel. `"essential"` is always allowed |
| `app.quiet:after(channel, fn)` | Runs `fn` now if the channel is allowed, or once it is. Returns a cancel function |

A channel is any name you choose for a kind of message: `"rewards"`,
`"competition"`. A running tour allows the `"tour"` channel only.

### Toasts

Toasts follow quiet mode by themselves. Give them a `channel` and say what
should happen to them while it is quiet:

```luau
app.toast("Level 2!", { channel = "rewards" })                 -- waits, shows after
app.toast("Next show in 1:00", { quiet = "drop" })             -- stale later: thrown away
app.toast.error("Disconnected", { quiet = "show" })            -- shows anyway
app.toast("Nice moves!", { channel = "tour" })                 -- the tour allows it
```

Toasts that waited show when quiet ends, the newest few only.

### Your own popups

Open your own prompts through `after`, and they wait for the tutorial too:

```luau
app.quiet:after("competition", function()
    rateDialog:open()
end)
```

Code that runs on its own (a nag on a timer) can check
`app.quiet:allows("competition")` instead, which is tracked, so a
`Lucy.useWhile` or `watchEffect` around it runs again when quiet ends.
