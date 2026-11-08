<!-- Made by scripts/skills.ts from docs/reference/composables/use-focus-scope.md. Edit the doc, not this file. -->
# useFocusScope

`Lucy.useFocusScope` isolates keyboard Tab navigation and gamepad selection
within a designated container frame while `active` is true. When activated, it
shifts focus to `defaultFocus` (or the first selectable element inside the
scope). When deactivated, it automatically restores focus to the element that
was focused prior to entering the scope.

## Usage

```luau
Lucy.useFocusScope(app?, active, options)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The app instance managing input and focus |
| `active` | `MaybeRef<boolean>` | required | While true, focus is trapped inside `root` |
| `options` | `table` | required | Configuration table (see below) |

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `root` | `GuiObject` | required | The boundary frame containing navigable items |
| `defaultFocus` | `GuiObject | (() -> GuiObject?)` | `nil` | Target to focus when scope activates |

## Example: Club Lucy VIP lounge modal

Keep controller focus confined within the confirmation modal so pressing the
D-pad or stick cannot highlight background dance floor elements:

```luau
local function VipConfirmDialog(h)
    local open = h:ref("open")
    local confirmButton = Lucy.ref(nil)

    local dialogRoot = Lucy.new "Frame" {
        Visible = open,
        Size = UDim2.fromOffset(360, 200),
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
