<!-- Made by scripts/skills.ts from docs/components/progress.md. Edit the doc, not this file. -->
# Progress

A bar that fills from 0 to a maximum, for hype, loading and a track's time left. It is
as wide as its parent, so put it in a sized frame or Stack.

```luau
Lucy.Stack.new({
    gap = "Space2",
    size = UDim2.fromOffset(360, 0),
    automaticSize = Enum.AutomaticSize.Y,
    children = {
        Lucy.Stack.new({
            direction = "horizontal",
            gap = "Space2",
            align = "center",
            children = {
                Lucy.Icon.new({ icon = "lucide-extended:flame-filled", variant = "warning" }),
                Lucy.Text.new({ text = "Crowd hype", variant = "label", autoWidth = true }),
            },
        }),
        Lucy.Progress.new({ id = "hype", value = 30, height = 12 }),
    },
    Parent = parent,
})

app.state:set("ui.hype.value", 75)
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `value` | number | `0` | yes | How full the bar is. Kept between 0 and `max` |
| `max` | number | `100` | yes | The value of a full bar |
| `variant` | string | `"default"` | yes | The bar's colour: `default`, `success`, `warning` or `destructive` |
| `visible` | boolean | `true` | yes | Shows or hides the bar |
| `height` | number | `8` | | The bar's height in pixels |

It also takes the [props every component takes](index.md#using-a-component).

## Examples

A hype meter that follows app state and turns red when the crowd goes cold:

```luau
local hype = app.state:ref("player.hype")

Lucy.Progress.new({
    value = hype,
    max = 100,
    height = 12,
    variant = function()
        return if hype() < 25 then "destructive" else "success"
    end,
    Parent = hud,
})
```

A loading bar driven by a count:

```luau
local loaded = Lucy.ref(0)

Lucy.Progress.new({ value = loaded, max = #clubAssets, Parent = loadingScreen })

for _, asset in clubAssets do
    ContentProvider:PreloadAsync({ asset })
    loaded(loaded() + 1)
end
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Progress")`.
