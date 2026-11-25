---
title: useDismiss
description: Closes floating content on Back (B, Backspace) or on a press outside it.
order: 22
---

# useDismiss

`Lucy.useDismiss` closes an open floating panel or tooltip when the player
presses Back (B or Backspace) or clicks/taps outside the listed elements.

## Usage

```luau
local dismiss = Lucy.useDismiss(app, open, {
    back = true,
    inside = { button, content },
})
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `App` | required | The app |
| `open` | `Ref<boolean>` | required | Writable ref set to `false` on dismiss |
| `options.back` | `boolean?` | `true` | Close on Back input |
| `options.inside` | `{ any }?` | | GuiObjects or handles whose bounds do not trigger outside dismissal |
| `options.hits` | `((GuiObject, Vector2) -> boolean)?` | | Custom hit test for outside presses |

Returns `{ press }` where `dismiss.press(point)` runs the outside check from
code or specs.
