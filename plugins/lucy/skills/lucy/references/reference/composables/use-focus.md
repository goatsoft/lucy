<!-- Made by scripts/skills.ts from docs/reference/composables/use-focus.md. Edit the doc, not this file. -->
# useFocus

`Lucy.useFocus` tracks whether `app.input:focusRef()` currently rests on
`target` or any descendant inside it.

## Usage

```luau
local focus = Lucy.useFocus(app, target)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `App` | required | The app |
| `target` | `GuiObject \| Handle` | required | The instance or handle to follow |

Returns `{ active }` where `focus.active()` is a tracked boolean getter.
