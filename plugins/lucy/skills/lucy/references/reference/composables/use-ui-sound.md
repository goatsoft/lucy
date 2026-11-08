<!-- Made by scripts/skills.ts from docs/reference/composables/use-ui-sound.md. Edit the doc, not this file. -->
# useUiSound

Lucy plays no audio directly. Components emit semantic events when players
interact with them (`activate`, `toggle`, `open`, `close`, `select`), and
`Lucy.useUiSound` listens for these events to trigger your game's sound effects.

## Usage

```luau
Lucy.useUiSound(app?, soundMap)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The app instance routing UI events |
| `soundMap` | `table` | required | Event callback mappings |

### Supported events

| Event | When it fires | Callback value |
|---|---|---|
| `activate` | A Button or Pressable is clicked | None |
| `toggle` | A Switch or Checkbox is turned on or off | `boolean` (new checked state) |
| `open` | A Dialog or sheet opens | None |
| `close` | A Dialog or sheet closes | None |
| `select` | An option is chosen in RadioGroup, ToggleGroup or Select | The selected value |

### Scoping and silencing

- **Innermost scope wins**: Lucy searches from the emitting component upwards
  through its parent reactive scopes. The first handler that names the event is
  called. Call `useUiSound` at the scene level for default sounds, and call it
  again in a specific panel to override sounds locally.
- **Passing `false` silences an event**: `{ activate = false }` silences buttons
  in busy rhythm mini-games.
- **Component prop `sound = false`**: Silences all sound events emitted by that
  specific component instance.
- **Safe error handling**: If a sound callback throws an error, the error is
  warned in output without breaking the player's interaction or click logic.

## Example: Club Lucy audio feedback

In Club Lucy, UI interactions trigger turntable scratch samples and button
thumps:

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
