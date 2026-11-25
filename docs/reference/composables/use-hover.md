---
title: useHover
description: Tracks pointer hover over a target with open and close delays and safe crossing.
order: 24
---

# useHover

`Lucy.useHover` tracks whether the pointer is over `target` (or any extra object
in `also`), with optional open and close delays and delay-group integration.

## Usage

```luau
local hover = Lucy.useHover(button, {
    delay = 0.4,
    closeDelay = 0.1,
    also = { tooltipBody },
    group = Lucy.useDelayGroup(app),
})
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `target` | `GuiObject \| Handle` | required | Control to watch |
| `options.delay` | `MaybeRef<number>?` | `0` | Seconds before turning active |
| `options.closeDelay` | `MaybeRef<number>?` | `0` | Seconds before turning inactive on leave |
| `options.also` | `{ any }?` | | Extra controls (such as an interactive tooltip) that keep hover active |
| `options.group` | `DelayGroup?` | | Shared group from `Lucy.useDelayGroup` |

Returns `{ active, enter, leave }`.
