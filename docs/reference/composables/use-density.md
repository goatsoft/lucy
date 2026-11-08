---
title: useDensity
description: Returns a getter for the current device density profile.
order: 1
---

# useDensity

`Lucy.useDensity` returns a getter that follows the theme's active density
profile (`"default"`, `"touch"` or `"tv"`). Every caller in an App shares the
same underlying reactive state, so calling it multiple times across different
components carries no extra overhead.

## Usage

```luau
local density = Lucy.useDensity(app?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The app instance to read density from |

### Returns

| Name | Type | What it is |
|---|---|---|
| `density` | `() -> "default" | "touch" | "tv"` | A getter returning the active density string |

## Example: Club Lucy responsive badge

In Club Lucy, badges can adjust their layout and font sizing when rendered on
touch devices or large TV screens:

```luau
local function DanceFloorBadge(h)
    local density = Lucy.useDensity(h.app)

    return Lucy.new "TextLabel" {
        Text = function()
            if density() == "touch" then
                return "Floor: Active (Touch)"
            elseif density() == "tv" then
                return "Dance Floor: Live Set"
            end
            return "Floor: Active"
        end,
        Tags = { "ui-badge" },
    }
end
```
