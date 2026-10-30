<!-- Made by scripts/skills.ts from docs/components/progress.md. Edit the doc, not this file. -->
# Progress

A bar that fills from 0 to a maximum, for reloads, loading and health.

```lua
Lucy.Progress.new({ id = "reload", value = 30, Parent = hud })

app.state:set("ui.reload.value", 75)
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `value` | number | `0` | yes | How full the bar is. Kept between 0 and `max` |
| `max` | number | `100` | yes | The value of a full bar |
| `visible` | boolean | `true` | yes | Shows or hides the bar |
| `height` | number | `8` | | The bar's height in pixels |

It also takes the [props every component takes](index.md#using-a-component).

## Examples

A health bar that follows app state:

```lua
local health = app.state:ref("player.health")

Lucy.Progress.new({ value = health, max = 100, height = 12, Parent = hud })
```

A loading bar driven by a count:

```lua
local loaded = Lucy.ref(0)

Lucy.Progress.new({ value = loaded, max = #assets, Parent = loadingScreen })

for _, asset in assets do
    ContentProvider:PreloadAsync({ asset })
    loaded(loaded() + 1)
end
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Progress")`.
