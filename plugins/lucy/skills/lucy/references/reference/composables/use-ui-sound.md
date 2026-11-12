<!-- Made by scripts/skills.ts from docs/reference/composables/use-ui-sound.md. Edit the doc, not this file. -->
# useUiSound

Lucy plays no audio of its own. Components report events when the player
interacts with them (`activate`, `toggle`, `open`, `close`, `select`), and
`Lucy.useUiSound` hooks those events to your game's sounds.

## Usage

```luau
Lucy.useUiSound(app?, soundMap)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The App routing UI events |
| `soundMap` | `table` | required | Map of event names to functions (or `false`) |

### Supported events

| Event | When it fires | Value passed |
|---|---|---|
| `activate` | A Button or Pressable is clicked | None |
| `toggle` | A Switch or Checkbox changes | `boolean` (new checked state) |
| `open` | A Dialog or Sheet opens | None |
| `close` | A Dialog or Sheet closes | None |
| `select` | A choice is picked in RadioGroup, ToggleGroup, Select or Tabs | The picked value |

### Scoping and silencing

- **Innermost scope wins**: Lucy walks up from the component through its
  parent scopes and calls the first handler that names the event. Set default
  sounds on the scene, then override them inside a panel when needed.
- **`false` silences an event**: `{ activate = false }` stops button sounds
  during a busy rhythm minigame.
- **`sound = false` on a component**: silences every event from that instance.
- **Errors stay contained**: an error in a sound function warns in the output
  without breaking the click itself.

## Example: audio feedback

Play sounds for clicks, switches, menus and selections:

```luau
Lucy.useUiSound(app, {
    activate = function(handle)
        sounds.clickThump:Play()
    end,
    toggle = function(handle, checked)
        if checked then
            sounds.switchOn:Play()
        else
            sounds.switchOff:Play()
        end
    end,
    open = function(handle)
        sounds.vinylScratch:Play()
    end,
    close = function(handle)
        sounds.vinylBackspin:Play()
    end,
    select = function(handle, trackValue)
        sounds.cueBeep:Play()
    end,
})
```
