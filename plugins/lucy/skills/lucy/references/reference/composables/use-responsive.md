<!-- Made by scripts/skills.ts from docs/reference/composables/use-responsive.md. Edit the doc, not this file. -->
# useResponsive

`Lucy.useResponsive` returns a getter that picks a value from `map` for the
player's current device, input mode, breakpoint or orientation. If you pass a
plain value instead of a map, it wraps it in a getter so callers can take either
the same way.

## Usage

```luau
local value = Lucy.useResponsive(app?, map)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The App tracking device and input state |
| `map` | `table` | required | Table mapping responsive keys to values |

### Keys

The first matching key wins, in this order:

1. **`device`**: `"mobile"`, `"tablet"`, `"desktop"`, `"console"`
2. **`mode`**: `"touch"`, `"gamepad"`, `"keyboard"`, `"mouse"`
3. **`breakpoint`**: `"compact"`, `"regular"`, `"wide"`
4. **`orientation`**: `"portrait"`, `"landscape"`
5. **`default`**: Used when nothing above matches

See [Responsive values](../../components/index.md#responsive-values).

### Returns

| Name | Type | What it is |
|---|---|---|
| `value` | `() -> any` | Resolved responsive value |

## Example: responsive HUD spacing

Widen the gap between items on touch screens and console TVs:

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
