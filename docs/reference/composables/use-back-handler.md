---
title: useBackHandler
description: Intercepts back inputs while active, calling your function.
order: 4
---

# useBackHandler

`Lucy.useBackHandler` registers a handler for back input actions (B on a gamepad
and Backspace on a keyboard) while an active condition is true. When back is
pressed, the most recently mounted active handler is called first (LIFO order).

Returning `true` from your callback marks the back event as handled and stops it
from bubbling down to underlying scenes, screens or handlers.

## Usage

```luau
Lucy.useBackHandler(app?, active, handler)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The app instance providing input dispatch |
| `active` | `MaybeRef<boolean>` | required | When true, this handler participates in back presses |
| `handler` | `() -> boolean?` | required | Callback executed on back press. Return `true` to stop |

## Back keys

Lucy maps **ButtonB** on gamepads and **Backspace** on keyboards as back keys.
**Escape is not used as a back key** because Roblox opens its own core engine
menu on every Escape press, which cannot be disabled.

For more information, see [Back keys](../../architecture.md#back-keys).

## Example: closing the Club Lucy emote wheel

When the emote wheel is opened, it registers a back handler so pressing B or
Backspace dismisses the menu cleanly:

```luau
local function EmoteWheel(h)
    local open = h:ref("open")

    Lucy.useBackHandler(h.app, open, function()
        open(false)
        return true -- Handled: prevents navigating away from the dance floor
    end)

    return Lucy.new "Frame" {
        Visible = open,
        Size = UDim2.fromOffset(300, 300),
    }
end
```
