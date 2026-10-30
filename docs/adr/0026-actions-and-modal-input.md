# 0026: Actions, modal input and two composables

- Status: accepted
- Date: 2026-10-31
- Amends: 0021 (what "modal input" ships as)

## Context

ADR 0021 asks for modal input: a reactive "a modal is open", and blocking
movement, jumping and hotkeys while one is. ADR 0024 publishes `overlay.modal`
for it to build on.

Dance Lab does this today with a `DialogManager`, an `AppState.ObserveActiveDialog`
listener and six hand written `UserInputService.InputBegan` handlers, each
checking `AppState.IsModalOpen()`. Its "modal input sink" calls
`ContextActionService:BindActionAtPriority` with no input types, so it binds
nothing: hotkeys are only blocked by the checks in each handler, and movement
and jumping are not blocked on keyboard at all. One menu (dances) wants focus
held but movement left alone, which the sink special cases by name.

Lucy has no hotkeys: games read raw keys, list keyboard and gamepad codes at
every call site, and cannot let players remap them.

LoP-Engine solved the same problem with named actions, bindings per device and
sets of actions switched on and off together. Roblox now ships that model in
the engine (the Input Action System): `InputContext` (a set, with `Enabled`,
`Priority` and `Sink`), `InputAction` (with `Pressed`, `Released`,
`StateChanged` and `PreferredBinding`) and `InputBinding` (a key, a button, a
composite direction, or a screen button for touch). A context with `Sink` above
the default player scripts' priority swallows its keys before the character
controls see them.

Blocking movement is the game's choice, not the overlay's: the dance menu shows
that the same kind of overlay needs different blocking in different games.

## Decision

### 1. `app:modalOpen()`

A method on the app, next to `setTheme` and `portal`: true while any modal
overlay is open (`overlay.modal > 0`), tracked, so anything reading it updates.
Overlays gain no blocking options. Non modal overlays never count (0024).

### 2. `app.actions`, built on the Input Action System

A game describes its actions in a table; Lucy creates the Roblox instances under
a folder the app owns (destroyed with the app) and keeps them in step with state.

```luau
app.actions:define("gameplay", {
	inventory = { Enum.KeyCode.I, Enum.KeyCode.ButtonL1 },
	shop = { Enum.KeyCode.B, Enum.KeyCode.DPadRight },
})

local stop = app.actions:on("inventory", function()
	inventory:toggle()
end)

app.actions:bind("inventory", { Enum.KeyCode.Tab })  -- remap, keyboard and gamepad
app.actions:bind({ inventory = { Enum.KeyCode.Tab }, shop = { Enum.KeyCode.P } })
app.actions:keys("inventory")                         -- the keys for the current device
local release = app.actions:disable("gameplay")       -- counted; release() undoes it
app.actions:enabled("gameplay")                       -- tracked boolean
```

- **Sets** are InputContexts. `define(set, actions, options?)` takes
  `priority` and `sink`; a set can be defined more than once to add actions.
- **Actions** are InputActions of type Bool for 0.1.0 (pressed and released).
  Action names are unique per app, so `on` and `bind` need no set name. A list
  of KeyCodes is the short form; Lucy makes one binding per code, and the
  gamepad codes (`Button*`, `DPad*`, `Thumbstick*`) are told apart by name for
  `keys`.
- **`on(name, handler)`** runs on press and returns a stop function; it is
  cleaned up with the current owner when there is one. Actions do not fire
  while a TextBox is focused (the engine already does this).
- **`disable(...)`** is counted per set: two disables of one set need two
  releases. The set's `Enabled` is bound to the count, never set by hand.
- **`bind(name, keys)`** replaces an action's bindings; `bind({ [name] = keys })`
  replaces several in one call (loading a player's saved keys), so hints and
  handlers never see half of them applied. A game saves the player's choice
  itself.
- Calls that change things take several at once (`disable`, `bind`, `define`);
  calls that read take one name (`keys`, `enabled`), and `on` takes one action.
- **`keys(name)`** splits the action's keys by `input.mode`, the mode Lucy's
  focus ring and navigation already follow (gamepad keys on a gamepad, none on
  touch, the rest otherwise), so Button `hint` and Kbd can show an action later
  without the game listing keys.

### 3. The built in `movement` set

Lucy does not move characters. `movement` names the keys the default character
controls use (W, A, S, D, the arrow keys, Space, the left stick). Disabling it
holds those keys until it is released. A game can redefine the set's keys.
Lucy never disables it on its own.

How it holds them depends on which default controls the game runs, set by
`Workspace.PlayerScriptsUseInputActionSystem`:

- **New controls** (Enabled; the default from early 2027, the only option from
  mid 2027): the controls are InputContexts under
  `StarterPlayer.PlayerModule.InputContexts` (`CharacterContext` at priority
  150, `CameraContext` at 100). Lucy turns on its own sinking InputContext at
  priority 2000. Keys still reach `UserInputService.InputBegan` as not
  processed, so InputManager is unaffected.
- **Old controls** (Disabled or Default today): an InputContext cannot stop
  them. Lucy binds the keys with ContextActionService above the default
  controls and sinks them. Those keys then reach `InputBegan` marked as
  processed, so InputManager treats keys held by Lucy's own `movement` block as
  not processed: arrows, Enter and Space keep working inside a modal.

Scripts cannot read the Workspace setting, so Lucy checks for
`StarterPlayer.PlayerModule.InputContexts.CharacterContext` on the client. The
old path goes when Roblox removes the old controls.

### 4. Composables

`Lucy.useWhile(condition, setup)`: `condition` is a ref or getter. Each time it
turns true, `setup` runs in its own scope and may return a cleanup function or
an RBXScriptConnection, or call `onCleanup`. All of it is cleaned up when the
condition turns false or the owner stops. It replaces Dance Lab's
`AppState.ConnectWhile`.

`Lucy.useCountdown(endsAt)`: `endsAt` is a number or ref in
`workspace:GetServerTimeNow()` time. Returns `{ remaining, done }`: whole
seconds left (never below 0) and a boolean. It ticks on each second boundary,
not every frame, and follows `endsAt` when it changes.

Modal input in a game is then a few lines, and the docs show it:

```luau
Lucy.useWhile(function()
	return app:modalOpen()
end, function()
	return app.actions:disable("gameplay", "movement")
end)
```

The dance menu case is the game's own condition (disable only `gameplay` while
that overlay is on top, from `app.state:ref("overlay.top")`).

### 5. Checked in Studio (2026-10-31)

Old controls (setting Disabled):

- The client has no InputContexts of its own.
- A sinking InputContext at priority 2000 bound to W fires its own action but
  does not stop the character, and `InputBegan` sees the keys as not
  processed. (Roblox staff on the forum: the old input path wins over
  InputContexts until the default controls move over.)
- A ContextActionService sink bound to W, Space and the arrows stops the
  character, and `InputBegan` sees those keys as processed.

New controls (setting Enabled):

- The default contexts are as listed in section 3, none sinking except
  `TransformerContext` (300) and the vehicle context (200, off on foot).
- A sinking InputContext at priority 2000 bound to W, A, S, D, Space and the
  arrows stops walking and jumping (0 studs, no rise; a control jump rose 7
  studs), and `InputBegan` sees every key as not processed.

Both:

- Input actions do not fire while a TextBox is focused.
- Not yet tried: a gamepad stick, and the touch thumbstick held when a modal
  opens.
- Forum reports of the new controls locking the camera over clickable
  ProximityPrompts and `Active` UI are open with Roblox; games on the new
  controls should check their prompts.

## Consequences

- One hotkey path with remapping and device aware hints, instead of raw key
  checks per call site.
- Blocking is decided by the game from state, so overlays stay simple and
  every case (dance menu, cutscenes, rhythm lanes) uses the same two pieces.
- Lucy depends on the Input Action System being available on every platform the
  game ships to.
- Dance Lab's `DialogManager`, `ObserveActiveDialog`, `ConnectWhile` and its
  sink are removed in the rebuild.
- Not in 0.1.0: direction and axis actions, a remapping screen, touch bindings
  to Lucy Buttons (an `action` prop), saving bindings.

## Alternatives considered

- **Blocking options on Overlay, Dialog and Sheet** (`blockMovement`).
  Rejected: blocking is a game decision, and the dance menu shows the same
  overlay needs different answers.
- **A `useInputTrap` composable.** Rejected for now: it would wrap the one line
  above, and "trap" already means a modal holding focus.
- **ContextActionService and our own action tables for everything.** Rejected:
  the engine now has sets, priorities, touch buttons and preferred bindings.
  ContextActionService stays for one job only: holding the movement keys in
  games still on the old default controls.
- **Switching the default character controls off.** Rejected: it fights games
  that already switch them off for dances and cutscenes.
- **`app.ui:modalOpen()`.** Rejected: a namespace for one method, and
  everything in Lucy is UI.
