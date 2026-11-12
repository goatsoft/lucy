---
title: Progress
description: A bar that fills from 0 to a maximum.
---

# Progress

A bar that fills from 0 to a maximum, for hype, loading and a track's time left. It is
as wide as its parent, so put it in a sized frame or Stack.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-progress-light.webp" alt="Progress example" loading="lazy"><img class="example-dark" src="/images/examples/components-progress-dark.webp" alt="Progress example" loading="lazy"></figure>

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
| `steps` | number | none | | Makes the bar a rail of this many numbered markers. See [Stepped](#stepped) |
| `stepSize` | number | `28` | | A marker's size in pixels, with `steps` |

It also takes the [props every component takes](index.md#using-a-component).

## Stepped

With `steps`, the bar becomes a rail of numbered markers: a battle pass's tiers, a quest's
stages. `value` is then counted in steps, and `max` is not used. The fill reaches marker 3's
centre when the value is 3, and each marker lights up once the value reaches it. A value between
two whole numbers fills part of the way to the next marker, for progress inside a step.

The markers are evenly spaced: marker `i` is centred at `(i - 0.5) / steps` of the width. Put the
rail above or below a row of equal columns that is as wide as the rail, and every marker sits on
its column's centre.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-progress-2-light.webp" alt="Progress example" loading="lazy"><img class="example-dark" src="/images/examples/components-progress-2-dark.webp" alt="Progress example" loading="lazy"></figure>

```luau
local tier = Lucy.ref(4)
local xp = Lucy.ref(600)

Lucy.Stack.new({
    gap = "Space3",
    children = {
        Lucy.Text.new({ text = "Club Lucy season pass: tier 4, 600 of 1,000 XP to tier 5", variant = "muted" }),
        Lucy.Progress.new({
            steps = 10,
            stepSize = 32,
            height = 10,
            value = function()
                return tier() + xp() / 1000
            end,
        }),
    },
    Parent = parent,
})
```

The markers take `$Secondary`, and `$Primary` once lit. To give a rail your game's colours, tag
its instance and add rules for `.ui-progress-step`, `.ui-progress-step-on` and
`.ui-progress-indicator` under your tag.

## Examples

A hype meter that follows app state and turns red when the crowd goes cold:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-progress-3-light.webp" alt="Progress example" loading="lazy"><img class="example-dark" src="/images/examples/components-progress-3-dark.webp" alt="Progress example" loading="lazy"></figure>

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
