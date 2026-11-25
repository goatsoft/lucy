---
title: useFocus
description: Tracks whether keyboard or gamepad focus is on a control or inside it.
order: 23
---

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
