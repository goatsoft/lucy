---
title: useMetric
description: Computes a control size token in pixels following density.
order: 2
---

# useMetric

`Lucy.useMetric` computes the resolved height in pixels of a control size token
(`ControlSm`, `ControlMd`, `ControlLg`, `ControlXl` or `ControlIcon`) for the
current device density. While control tokens are full `UDim2` values in
Universal Styling rules, `useMetric` returns their numeric pixel height for use
in code calculations and dynamic sizing.

## Usage

```luau
local height = Lucy.useMetric(app?, tokenName)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The app instance to derive metrics from |
| `tokenName` | `string` | required | One of `"ControlSm"`, `"ControlMd"`, `"ControlLg"`, `"ControlXl"`, `"ControlIcon"` |

### Returns

| Name | Type | What it is |
|---|---|---|
| `height` | `() -> number` | A computed getter returning the token height in pixels |

## Example: Club Lucy DJ deck controls

In the DJ Booth, row items match the standard control height across mobile,
desktop and console:

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
