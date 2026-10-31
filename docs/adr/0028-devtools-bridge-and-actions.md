# 0028: Devtools reach the game through a bridge, and can act

- Status: accepted (JB, 2026-10-31)
- Date: 2026-10-31
- Amends: 0027 (section 2, `Lucy.Devtools`)

## Context

ADR 0027 plans `Lucy.Devtools` as plain functions an agent calls with Studio's
`execute_luau`, reading what Lucy already tracks.

Measured in LucyTests (2026-10-31), during Play, `execute_luau` on the Client
data model:

- `require(ReplicatedStorage.Lucy)` returns a separate copy of the module, not
  the one the game's LocalScripts loaded. A field one sets is not seen by the
  other. `_G` and `shared` are separate too. So Devtools called from an agent
  cannot see the game's App at all.
- A BindableFunction made by a game script can be invoked from `execute_luau`.
  Tables, nested tables, Instances and functions come back intact.

The same session ran five agents with only the skills (settings menu, shop,
HUD, pause menu, inventory) and tried their scripts in Studio:

- Studio's input tool cannot click GUI buttons. A plain `TextButton` ignored
  `user_mouse_input` clicks at its exact position. Keys bound to actions (M, B,
  Escape) arrive; arrow keys and Enter do not move or press the selection.
- So an agent can open a menu with its hotkey and take a screenshot, but cannot
  press a button, pick a tab, move focus or check what a click does.

## Decision

### The bridge

In Studio (`RunService:IsStudio()`), `App.new` makes a BindableFunction named
`<namePrefix>Devtools`, tagged `LucyDevtools`, in the app's gui parent. It is
destroyed with the app. Live games never get one. `App.new({ devtools = false })`
turns it off.

Its `OnInvoke` requires `Core/Devtools` only when first called, so Devtools
still costs nothing until an agent uses it.

Every Devtools function finds the app to work on through the bridge: the only
one when there is one, or the one named by `options.app` (its `namePrefix`).
An App table passed as `options.app` is used directly, which is how specs and
stories call it. Results are plain tables of strings, numbers and booleans, so
`execute_luau` prints them as they are.

### Actions as well as reads

Besides the reads in 0027 (`apps`, `tree`, `focus`, `overlays`, `actions`,
`state`, `preview`), Devtools can act the way a player would:

- `press(id, value?)`: clicks the component (`handle:click()`), or picks
  `value` in a group, tabs, select or radio group (`handle:select(value)`).
  Disabled components ignore it, as they ignore the player.
- `set(path, value)`: writes app state.
- `focus(id?)`: with an id, moves focus to that component, as a gamepad
  player would land on it; it always returns what is focused and the input
  mode.

These run through the same code paths as the player's input, so a test with
them tests the game, not a shortcut.

## Consequences

- One BindableFunction per app in Studio. Nothing in live games.
- Agents can test a menu end to end: open it with its key, press, read state,
  screenshot.
- Devtools results are copies, so an agent cannot hold onto a live handle
  across calls. Ids are the handles.

## Alternatives considered

- **Devtools reads only, as 0027 had it.** With clicks and arrow keys not
  reaching the game, an agent could look but not test.
- **A bridge only when the game opts in** (`Lucy.Devtools.expose(app)`).
  Every agent session would start with editing the game to turn it on.
- **Read the instance tree only, no bridge.** Tags and names show what is on
  screen, but not app state, focus, overlays or actions.
