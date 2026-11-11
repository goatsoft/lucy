<!-- Made by scripts/skills.ts from docs/reference/composables/use-focus-zone.md. Edit the doc, not this file. -->
# useFocusZone

`Lucy.useFocusZone` makes a group of controls a zone the gamepad steps into
with a key. Use it for controls that must not hold the selection while the
player plays (a HUD card, a column of buttons beside the play area): while
anything is selected, the left stick moves the selection instead of the
character, so nothing is selected until the player asks.

With nothing selected, a key in `keys` steps in and focus lands on the zone's
first or last control. Inside, the D-pad and keys stay on the zone's controls
and A presses. B (or Backspace) steps back out and leaves nothing selected, so
the stick walks again. Focus going anywhere else (a click, a menu opening, the
zone hiding) leaves the zone too. The mouse and touch are not affected.

## Usage

```luau
local zone = Lucy.useFocusZone(app?, root, options)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The app managing input and focus |
| `root` | `MaybeRef<GuiObject?>` | required | The frame holding the zone's controls |
| `options` | `table` | required | See below |

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `name` | `string` | required | Unique in the app; the keys are the action set `zone:<name>` |
| `keys` | `{ [Enum.KeyCode]: "first" \| "last" \| (list) -> GuiObject? }` | `{}` | The keys that step in, and where each lands (reading order) |
| `enabled` | `MaybeRef<boolean>` | `true` | When stepping in is allowed (the zone is shown, nothing else has the key) |
| `priority` | `number` | the actions default | The action set's priority |

The keys work only while `enabled` is true, nothing is selected and no modal is
open. The rest of the time they reach whatever else binds them.

### Returns

| Field | Type | What it is |
|---|---|---|
| `inside` | `() -> boolean` | Tracked: focus is in the zone |
| `enter` | `(where?) -> ()` | Steps in (`"first"`, `"last"` or a function), as a key does |
| `leave` | `() -> ()` | Steps out |

## Example: a player card at the top of the HUD

D-pad up steps onto the card's top button; D-pad up and down then move between
its rows, A presses, B steps out:

```luau
local card = PlayerCard.new({ Parent = scene.gui })

Lucy.useFocusZone(app, card, {
    name = "hudCard",
    keys = { [Enum.KeyCode.DPadUp] = "first" },
    enabled = function()
        return not onStage() and not showHasTheDPad()
    end,
})
```

## Example: cheers beside the stage

D-pad up steps in at the bottom cheer, D-pad down at the top one, and a hint
shows while the player is in them:

```luau
local zone = Lucy.useFocusZone(app, cheers, {
    name = "cheers",
    keys = { [Enum.KeyCode.DPadUp] = "last", [Enum.KeyCode.DPadDown] = "first" },
    enabled = cheersShown,
})

Lucy.Text.new({
    text = "B to leave the cheers",
    visible = zone.inside,
})
```

## Zone, tile or scope?

| You want | Use |
|---|---|
| A list row with several controls to be one stop | [Item with `focus = "tile"`](../../components/item.md#one-stop-per-row) |
| A group nothing selects until a key steps in | `useFocusZone` |
| A dialog or panel that keeps focus while it is open | A Dialog or Sheet, or [`useFocusScope`](use-focus-scope.md) |

How input and focus are routed is in [Architecture](../../architecture.md#input-and-focus).
