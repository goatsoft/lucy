<!-- Made by scripts/skills.ts from docs/reference/composables/use-metric.md. Edit the doc, not this file. -->
# useMetric

`Lucy.useMetric` returns the height in pixels of a control size token
(`ControlSm`, `ControlMd`, `ControlLg`, `ControlXl` or `ControlIcon`) for the
current density. Style rules use full `UDim2` tokens; `useMetric` gives the
plain pixel number when code computes sizes or positions.

## Usage

```luau
local height = Lucy.useMetric(app?, tokenName)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The App to read metrics from |
| `tokenName` | `string` | required | One of `"ControlSm"`, `"ControlMd"`, `"ControlLg"`, `"ControlXl"`, `"ControlIcon"` |

### Returns

| Name | Type | What it is |
|---|---|---|
| `height` | `() -> number` | Token height in pixels |

## Example: DJ deck controls

Match row heights to the control metric across phone, desktop and console:

```luau
local function BoothChannelRow(h)
    local height = Lucy.useMetric(h.app, "ControlMd")

    return Lucy.new "Frame" {
        Size = function()
            return UDim2.new(1, 0, 0, height())
        end,
        BackgroundTransparency = 1,
        Lucy.new "TextLabel" {
            Text = "Deck A Volume",
            Size = UDim2.fromScale(0.5, 1),
        },
    }
end
```
