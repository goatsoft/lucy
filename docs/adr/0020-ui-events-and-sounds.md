# 0020: UI events for game sounds; Lucy plays no audio

- Status: accepted
- Date: 2026-10-31

## Context

Every game plays sounds for its UI: a click per button, a switch sound, a whoosh
when a dialog opens. Roblox Dance Lab, the first game moving to Lucy, does this
with a helper that hooks every button under its HUD and an attribute to opt one
out (rhythm lane buttons must not click on every note).

Sound choice, assets and volumes belong to the game. Lucy shipping audio would
mean shipping asset ids, a mixer opinion and settings for both.

## Decision

1. **Lucy plays no audio.** Components report what the player did; the game
   decides what it sounds like.
2. **Components emit a small fixed set of events** with `h:emit(event, value)`:
   `activate` (Button, Pressable, through `Component.clickable`), `toggle` with
   the new checked state (Switch, Checkbox, from `toggle()`, so player toggles
   only), `open` and `close` (Dialog, not at mount), and `select` with the value
   for selection components to come. Game built components emit the same way.
3. **`Lucy.useUiSound(app, map)`** maps events to the game's functions, each
   called with `(handle, value)`. It registers on its owner and stops with it.
   Lookup, in `Core/UiEvents.luau`:
   - from the emitting component's scope up through its owners, the first map
     that names the event wins, and `false` there silences it;
   - otherwise the newest map registered in a top level scope (one with no
     owner) is used, so components made by plain scripts are covered;
   - `sound = false` in a component's props silences that component;
   - a function that errors is reported, never raised, so a sound cannot break
     a click.
4. **`Component.clickable(handle)`** is the shared click path for anything
   pressable: `handle.Activated`, `handle:click()`, the `onClick` prop, the
   50 ms guard against a doubled Enter, and the `activate` event.

## Consequences

- A scene can have its own sounds by calling `useUiSound` in its scope; part of
  a scene can override a few events, or silence them, without affecting the
  rest.
- Lookup follows ownership (where a component was made), not the instance tree
  (where it was parented). That matches how Lucy scopes everything else, and is
  documented on the composables reference page.
- Mount cost is unchanged: emitting allocates nothing until a map is found.

## Alternatives considered

- **App config with sound ids** (`App.new({ sounds = { click = id } })`). Puts
  assets and playback in Lucy; rejected by the owner.
- **A single app level signal** the game connects to. Works, but gives no way to
  scope sounds to a scene or silence part of the UI without filtering by hand.
- **Lookup by instance ancestry.** Would need a registered root instance per map;
  the owner chain is already there and costs nothing to walk.
