<!-- Made by scripts/skills.ts from docs/reference/composables/use-delay-group.md. Edit the doc, not this file. -->
# useDelayGroup

`Lucy.useDelayGroup` returns the app's shared delay group for floating content
such as [Tooltips](../../components/tooltip.md). The first tooltip waits its
full delay; moving to another tooltip while one is open (or within `skip`
seconds after it closes) opens the next right away, and claiming the group
closes the previous open one.

## Usage

```luau
local group = Lucy.useDelayGroup(app, { skip = 0.3 })
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `App` | required | The app whose delay group to share |
| `options.skip` | `number?` | `0.3` | Seconds after closing during which the next delay is skipped |

Returns `{ wait, claim, release, current, skip }`.

## Example

```luau
local group = Lucy.useDelayGroup(app)
local waitTime = group.wait(0.4) -- 0.4 on cold open, 0 when warm

task.delay(waitTime, function()
    group.claim("shopTip", function()
        open(false)
    end)
    open(true)
end)
```
