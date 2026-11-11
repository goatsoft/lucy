<!-- Made by scripts/skills.ts from docs/components/effect.md. Edit the doc, not this file. -->
# Effect

A little animated picture that celebrates something: a reward landing, a level
up, a prize. Put it behind (or over) the thing it celebrates. Lucy comes with
`rays` and `outline`, and you can add your own types.

```luau
local reward = Lucy.new("Frame", {
    Size = UDim2.fromOffset(220, 220),
    BackgroundTransparency = 1,
    Parent = dialog,
})
local burst = Lucy.Effect.new({ type = "rays", variant = "warning", Parent = reward })
Lucy.Icon.new({
    icon = "lucide-extended:trophy-filled",
    size = "xl",
    Parent = reward,
})

-- The moment the reward lands
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
| `type` | string | | | Which effect: `rays`, `outline`, or a type you registered |
| `variant` | string | `"primary"` | yes | The colours: `primary`, `warning`, `success` or `foreground` |
| `size` | UDim2 | the parent's size | | The effect's box |
| `visible` | boolean | `true` | yes | Shows or hides it; showing it plays the opening again |
| `still` | boolean | `false` | | Draws the picture with its opening done and nothing moving, for a decoration that should not animate |

Each type takes its own options as props too. It also takes the
[props every component takes](index.md#using-a-component).

`handle.running` says whether it is animating, `handle.stage` is the square it
draws in and `handle.content` is the type's picture.

## Rays

A starburst, as light glints off something shiny: brightest in the middle and
dimmer the further out. A glow with a white hot centre sits over layers of soft
rays. At the back are long, thin, faint ones; each layer in front has fewer,
shorter, wider and brighter rays, and the front one is a white four point glint.
They fan out from the middle one after another, then slowly turn, every other
layer the other way. While it runs it gleams, as loot does: the burst swells a
little and each ray flares for a moment at its own time.

```luau
Lucy.Effect.new({ type = "rays", variant = "warning", Parent = levelStage })
```

| Option | Type | Default | What it does |
|---|---|---|---|
| `count` | number | `12` | Rays in the back layer (each layer in front has fewer) |
| `layers` | number | `3` | How many layers of rays |
| `spin` | number | `18` | Degrees a second the back layer turns (`0`: still) |
| `width` | number | `0.28` | The front layer's rays, as a share of the burst |
| `core` | boolean | `true` | The glow in the middle |
| `pulse` | boolean | `true` | The gleam: the swell and the flares |

The glow reaches a little past the burst's square, so give it room to fade out
(nothing that clips, such as a CanvasGroup, right at its edge).

The parts are on the handle: `handle.layers` (each `{ rays, arms, wheel }`, back
first), `handle.rays` (every ray), `handle.core` (the glow, then its hot centre)
and `handle.pulse` (the UIScale it swells by). Each ray carries
`ui-effect-rays-ray`, `ui-effect-rays-ray-<variant>`, `ui-effect-rays-layer-<n>`
(from 1 at the back) and `ui-effect-rays-front` on the front layer; the glow
carries `ui-effect-rays-core`, and its centre `ui-effect-rays-hot`, for your own
styling.

## Outline

Light that follows the shape of what it is behind: a button, a card, a plate. A
soft glow sits round the whole edge, a steady rim runs along it, and a bright
stretch of light runs round and round the rim. It fades in, then keeps running,
and the glow breathes a little. Use it to call the player to one thing: a reward
to claim, the better of two offers.

```luau
local box = Lucy.new("Frame", {
    Size = UDim2.fromOffset(220, 48),
    BackgroundTransparency = 1,
    Parent = parent,
})
Lucy.Button.new({ text = "Claim reward", size = UDim2.fromScale(1, 1), Parent = box })
Lucy.Effect.new({ type = "outline", variant = "warning", radius = 8, Parent = box })
```

Unlike rays, the outline fills its whole box, whatever its shape, so give it
the box of the thing it lights. The light is drawn just outside the box's edge:
leave it a few pixels of room, and set `radius` to the corner radius of the
thing it lights.

| Option | Type | Default | What it does |
|---|---|---|---|
| `radius` | number | `8` | The corner radius, in pixels |
| `thickness` | number | `2` | The rim, in pixels |
| `speed` | number | `140` | Degrees a second the light runs (`0`: no running light) |
| `glow` | boolean | `true` | The soft glow round the edge |
| `pulse` | boolean | `true` | The glow breathes |

The parts are on the handle: `handle.glow`, `handle.rim` and `handle.light`
(the three frames) and `handle.sweep` (the UIGradient that turns). They carry
`ui-effect-outline-glow`, `ui-effect-outline-rim` and `ui-effect-outline-light`,
and each `ui-effect-outline-<variant>`, for your own styling.

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

### Textures

`Lucy.Effect.textures` has soft images for drawing light, white with their shape
in the transparency, so tint them with `ImageColor3`:

| Name | What it is |
|---|---|
| `streak` | One ray of light pointing up: brightest and widest at its base (the bottom edge), fading to a point. Stretch it to any length and width |
| `glow` | A round glow, hot in the middle, falling off smoothly to nothing at the edge |

```luau
Lucy.new("ImageLabel")({
    Image = Lucy.Effect.textures.glow,
    ImageColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(0.5, 0.5),
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Effect")`.
