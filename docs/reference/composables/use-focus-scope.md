---
title: useFocusScope
description: Traps keyboard and gamepad focus inside a container while active.
order: 5
---

# useFocusScope

`Lucy.useFocusScope` keeps keyboard Tab navigation and gamepad selection inside
a container frame while `active` is true. When activated, it moves focus to
`defaultFocus` (or the first selectable element inside `root`). When deactivated,
it restores focus to the element that had focus before the scope opened.

## Usage

```luau
Lucy.useFocusScope(app?, active, options)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The app instance managing input and focus |
| `active` | `MaybeRef<boolean>` | required | While true, focus stays inside `root` |
| `options` | `table` | required | Options table |

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `root` | `GuiObject` | required | Boundary frame holding the focusable items |
| `defaultFocus` | `GuiObject \| (() -> GuiObject?)` | `nil` | Target to focus when the scope activates |

## Example: Club Lucy VIP lounge modal

Keep controller focus inside a confirmation modal so pressing the D-pad or
stick cannot move to elements on the dance floor behind it:

```luau
local function VipConfirmDialog(h)
    local open = h:ref("open")
    local confirmButton = Lucy.ref(nil)

    local dialogRoot = Lucy.new "Frame" {
        Visible = open,
        Size = UDim2.fromOffset(360, 200),

        Lucy.new "TextButton" {
            [Lucy.instance] = confirmButton,
            Text = "Enter VIP",
            Size = UDim2.fromOffset(140, 40),
        },
    }

    Lucy.useFocusScope(h.app, open, {
        root = dialogRoot,
        defaultFocus = function()
            return confirmButton()
        end,
    })

    return dialogRoot
end
```
