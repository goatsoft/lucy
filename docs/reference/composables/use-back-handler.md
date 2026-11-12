---
title: useBackHandler
description: Intercepts back inputs while active, calling your function.
order: 4
---

# useBackHandler

`Lucy.useBackHandler` calls `handler` when the player presses back (B on a
gamepad or Backspace on a keyboard) while `active` is true. Handlers run newest
first: if several are active, the last one mounted gets the press.

Returning `true` stops the press there so nothing underneath sees it.

## Usage

```luau
Lucy.useBackHandler(app?, active, handler)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The App routing input |
| `active` | `MaybeRef<boolean>` | required | Runs the handler only while true |
| `handler` | `() -> boolean?` | required | Called on back press. Return `true` to handle it |

## Back keys

Lucy treats **ButtonB** on gamepads and **Backspace** on keyboards as back.
**Escape is not a back key** because Roblox always opens its own menu on
Escape.

See [Back keys](../../architecture.md#back-keys).

## Example: closing the emote wheel

Register a back handler while the wheel is open so B or Backspace closes it:

```luau
local function EmoteWheel(h)
    local open = h:ref("open")

    Lucy.useBackHandler(h.app, open, function()
        open(false)
        return true -- handled, so the scene underneath stays put
    end)

    return Lucy.new "Frame" {
        Visible = open,
        Size = UDim2.fromOffset(300, 300),
    }
end
```
