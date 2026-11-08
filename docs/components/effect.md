---
title: Effect
description: An animated celebration behind a reward or a level up, in types you can add to.
---

# Effect

A little animated picture that celebrates something: a reward landing, a level
up, a prize. Put it behind (or over) the thing it celebrates. Lucy comes with
`rays`, and you can add your own types.

```luau
local reward = Lucy.new("Frame")({
    Size = UDim2.fromOffset(220, 220),
    BackgroundTransparency = 1,
    Parent = dialog,
})
local burst = Lucy.Effect.new({ type = "rays", variant = "warning", Parent = reward })
Lucy.Image.new({ image = potionIcon, size = UDim2.fromOffset(96, 96), Parent = reward })

-- the moment the reward lands
burst:play()
```

The picture fills a square as big as the smaller side of its box, centred in
it. It plays its opening each time it is shown, and `effect:play()` plays it
again. Some types keep moving after the opening (rays turn). Nothing runs while
the effect is hidden, and it stops when destroyed. When the player asks for
reduced motion, the picture is simply there, still.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `type` | string | | | Which effect: `rays`, or a type you registered |
| `variant` | string | `"primary"` | yes | The colours: `primary`, `warning`, `success` or `foreground` |
| `size` | UDim2 | the parent's size | | The effect's box |
| `visible` | boolean | `true` | yes | Shows or hides it; showing it plays the opening again |

Each type takes its own options as props too. It also takes the
[props every component takes](index.md#using-a-component).

`handle.running` says whether it is animating, `handle.stage` is the square it
draws in and `handle.content` is the type's picture.

## Rays

Rays fan out from the middle one after another, then slowly turn. Every other
ray is fainter, and each fades in from the middle and out to its tip.

| Option | Type | Default | What it does |
|---|---|---|---|
| `count` | number | `12` | How many rays round the circle |
| `spin` | number | `18` | Degrees a second it turns (`0`: still) |
| `width` | number | `0.06` | Each ray's width, as a share of the burst |

The rays are on the handle (`handle.rays`) and carry `ui-effect-rays-ray`,
`ui-effect-rays-ray-alt` (every other one) and `ui-effect-rays-ray-<variant>`,
for your own styling.

## Your own types

Register a type once, then use it like a built-in one. It only draws: the effect
times it, hides it and respects reduced motion for you.

```luau
Lucy.Effect.register("halo", {
    intro = 0.4,       -- seconds the opening takes
    loop = true,       -- keeps running after the opening
    defaults = { pulse = 0.08 },
    rules = {
        { selector = ".my-halo", properties = { BackgroundColor3 = "$Primary" } },
    },
    render = function(ctx)
        return Lucy.new("Frame")({
            Tags = { "my-halo" },
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = function()
                local grow = math.min(ctx.intro() / 0.4, 1)
                local beat = 1 + ctx.option("pulse") * math.sin(ctx.elapsed() * 4)
                return UDim2.fromScale(0.8 * grow * beat, 0.8 * grow * beat)
            end,
            Lucy.new("UICorner")({ CornerRadius = UDim.new(1, 0) }),
        })
    end,
})

Lucy.Effect.new({ type = "halo", Parent = reward })
```

`render` builds the picture once and binds it to the context:

| | What it is |
|---|---|
| `ctx.intro()` | Seconds into the opening, stopping at `intro` |
| `ctx.elapsed()` | Seconds the effect has been running (a `loop` type only) |
| `ctx.variant()` | The current variant |
| `ctx.option(name)` | One of the type's options: the prop, or its default |
| `ctx.handle` | The effect, to put parts on for your own code |

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Effect")`.
