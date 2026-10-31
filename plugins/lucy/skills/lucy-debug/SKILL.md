---
name: lucy-debug
description: Check a Lucy UI in Roblox Studio with Lucy.Devtools and Studio's MCP server. Use after building or changing UI in a Lucy game, when a menu, button, hotkey or screen does not work, when asked to test, verify or screenshot UI, or when execute_luau cannot see the game's Lucy app.
---

# Checking Lucy UI in Studio

Build with the `lucy` skill; check with this one. You need Studio's MCP server
(`execute_luau`, `start_stop_play`, `screen_capture`, `user_keyboard_input`,
`get_console_output`). Read [Devtools](references/reference/devtools.md) for
every function.

## The one thing to know

Code you run with `execute_luau` gets **its own copy of Lucy**. It cannot see
the App the game's scripts made: `require(...Lucy)` there is a fresh module,
and `_G` is separate too. `Lucy.Devtools` reaches the game's App for you, in
Studio only. Never make a second App to inspect the first.

## The loop

1. `start_stop_play` to start. Wait a second or two for the game's scripts.
2. Run Devtools with `execute_luau` on the **Client** data model:
   ```lua
   local Devtools = require(game.ReplicatedStorage.Packages.Lucy).Devtools
   return Devtools.apps()
   ```
   Use the path the game requires Lucy from. Each call returns plain tables,
   which `execute_luau` prints.
3. Look before acting: `Devtools.tree({ shownOnly = true })` lists what is on
   screen with ids, text, state and flags; `Devtools.state(path)` reads the
   store.
4. Act the way a player would: open a menu with its hotkey
   (`user_keyboard_input`, see below) or `Devtools.press(id)`; pick values with
   `Devtools.press(id, value)`; move focus with `Devtools.focus(id)`.
5. Check the result: read state again, then `screen_capture` to see it.
6. Read errors: `get_console_output`. A scene that failed to build says
   `scene "Name" failed to build` with the reason; an unknown icon warns
   `unknown icon "set:name"` and draws nothing.
7. `start_stop_play` to stop before editing scripts.

A short report of a check works well: what you pressed, the state before and
after, and the screenshot.

## What Studio's input tool can and cannot do

- **Keys bound to actions arrive**: a game's own hotkeys (M, B, Escape, I)
  work through `user_keyboard_input`. Use them to test hotkeys for real.
- **Mouse clicks do not reach GUI buttons**, not even a plain TextButton, and
  arrow keys and Enter do not move or press the selection. Use
  `Devtools.press` and `Devtools.focus` instead; they run the same code as a
  click or a gamepad press.
- `screen_capture` images are larger than the viewport, so positions in a
  screenshot are not screen positions.

## Ids

Find ids in `Devtools.tree()`. Components without an `id` get one like
`button-3`, which changes when the UI changes; when you write UI, give an `id`
to anything a test will press or game code will reach.

## Without Play

To look at one piece of UI, preview its story in edit mode, no Play needed:
`Devtools.preview("Button")` (or `Lucy.Preview.show`), then `screen_capture`.
See [Stories and preview](references/stories.md).

## When Devtools errors

- "no Lucy app is running here": not in Play, or the code ran on the Server or
  Edit data model. Use Client.
- "several apps run": pass `{ app = "Lucy_" }` (the error lists the names).
- "did not answer": the game is busy or stopped; try again after a moment.
