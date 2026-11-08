---
title: useResponsive
description: Returns a getter for a responsive value keyed by device, input mode, breakpoint or orientation.
order: 3
---

# useResponsive

`Lucy.useResponsive` returns a getter for a responsive value table, evaluated
against the player's active device and input profile. If passed a plain value,
it wraps it in a getter so you can bind both plain and responsive values with
the exact same syntax.

## Usage

```luau
local value = Lucy.useResponsive(app?, map)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The app instance providing device and input state |
| `map` | `table` | required | A table mapping device/input keys to resolved values |

### Keys

The first matching key in this priority order wins:

1. **`device`**: `"mobile"`, `"tablet"`, `"desktop"`, `"console"`
2. **`mode`**: `"touch"`, `"gamepad"`, `"keyboard"`, `"mouse"`
3. **`breakpoint`**: `"compact"`, `"regular"`, `"wide"`
4. **`orientation`**: `"portrait"`, `"landscape"`
5. **`default`**: Fallback value when no other key matches

For more details on responsive keys, see
[Responsive values](../../components/index.md#responsive-values).

### Returns

| Name | Type | What it is |
|---|---|---|
| `value` | `() -> any` | A reactive getter returning the resolved responsive value |

## Example: Club Lucy responsive layout

Adjust spacing and column padding between phones and console TVs in the Club
Lucy dance floor HUD:

```luau
local function DanceFloorHUD(h)
    local gap = Lucy.useResponsive(h.app, {
        console = 24,
        touch = 16,
        default = 8,
    })

    return Lucy.new "Frame" {
        Size = UDim2.fromScale(1, 1),
        Lucy.new "UIListLayout" {
            Padding = function()
                return UDim.new(0, gap())
            end,
            FillDirection = Enum.FillDirection.Horizontal,
        },
    }
end
```
