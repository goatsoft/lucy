<!-- Made by scripts/skills.ts from docs/reference/composables/use-press.md. Edit the doc, not this file. -->
# usePress

`Lucy.usePress` tracks mouse and touch presses on `target` in `"hold"` mode
(active while held down, or after `longPress` seconds) or `"toggle"` mode
(flips on each press).

## Usage

```luau
local held = Lucy.usePress(card)
local toggled = Lucy.usePress(infoButton, { mode = "toggle" })
local long = Lucy.usePress(item, { longPress = 0.45 })
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `target` | `GuiObject \| Handle` | required | Control to watch |
| `options.mode` | `string?` | `"hold"` | `"hold"` or `"toggle"` |
| `options.longPress` | `number?` | `0` | Seconds held before activating in hold mode |

Returns `{ active, press, release }` where `active` is a writable `Ref<boolean>`.
