<!-- Made by scripts/skills.ts from docs/reference/composables/use-density.md. Edit the doc, not this file. -->
# useDensity

`Lucy.useDensity` returns a getter for the theme's active density profile
(`"default"`, `"touch"` or `"tv"`). Every call in the same App reads one shared
value.

## Usage

```luau
local density = Lucy.useDensity(app?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `Lucy.App?` | `Lucy.App.current()` | The App to read density from |

### Returns

| Name | Type | What it is |
|---|---|---|
| `density` | `() -> "default" \| "touch" \| "tv"` | Active density profile |

## Example: responsive badge

Swap text or layout for touch screens and TVs:

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
