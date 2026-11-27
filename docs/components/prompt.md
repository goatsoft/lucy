---
title: Prompt
description: An interaction prompt in the world with a key for the player's device, action text, hold progress and ProximityPrompt restyling.
---

# Prompt

Replaces Roblox's default proximity prompt with a themed Lucy prompt that
shows a rounded [Kbd](kbd.md) key cap inside a circular [Progress](progress.md)
hold ring, picks only the nearest prompt when several share an action, and can
restyle existing `ProximityPrompt` instances across the whole game.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-prompt-light.webp" alt="Prompt example" loading="lazy"><img class="example-dark" src="/images/examples/components-prompt-dark.webp" alt="Prompt example" loading="lazy"></figure>

```luau
app.actions:define("gameplay", {
    interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
})

Lucy.Prompt.new({
    target = workspace.Booth.Console,
    action = "interact",
    actionText = "Play a set",
    objectText = "DJ Booth",
    distance = 10,
    hold = 0.6,
    onTrigger = function()
        boothSheet:open()
    end,
})
```

## Actions and keys per device

When `action` names a [Lucy action](../guide/actions.md), the prompt's
[Kbd](kbd.md) key cap reads `app.actions:keys(action)` and updates live if the
player rebinds keys or switches between keyboard and controller.

On touch devices, `Kbd` shows `"Hold"` when `hold > 0` or `"Tap"` (or your own
`touch` label), and players can tap or hold the prompt pill directly on screen.

If you are not using `app.actions`, pass `keyboard`, `gamepad` and `touch`
directly.

## Hold to trigger

Set `hold` to the number of seconds the player must hold the key or press the
prompt. A circular [Progress](progress.md#circular) ring wraps the rounded
[Kbd](kbd.md) key cap and fills clockwise while holding. Letting go early or
walking out of `distance` cancels the hold and resets the ring.

## Nearest prompt

With `exclusive = true` (the default), when more than one prompt sharing the
same action or key is inside its `distance`, only the nearest enabled prompt is
active and responds to presses. Set `showWhenInactive = true` if farther prompts
should stay visible and dimmed instead of hiding.

## Variants and custom content

`Prompt` shares the same look options as [Tooltip](tooltip.md):

- `variant`: `default`, `inverse`, `primary`, `secondary`, `outline`, `destructive`, `overlay` or registered via `Lucy.Prompt.addVariant`.
- `size`: `sm`, `md` or `lg`.
- `border`, `fill`, `transparency`, `radius`.
- `children` or `content`: place extra badges, icons or counters in the prompt row.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-prompt-2-light.webp" alt="Prompt example" loading="lazy"><img class="example-dark" src="/images/examples/components-prompt-2-dark.webp" alt="Prompt example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    wrap = true,
    children = {
        Lucy.Prompt.new({
            keyboard = Enum.KeyCode.E,
            actionText = "Queue",
            variant = "default",
        }),
        Lucy.Prompt.new({
            keyboard = Enum.KeyCode.G,
            actionText = "Dance",
            variant = "inverse",
        }),
        Lucy.Prompt.new({
            keyboard = Enum.KeyCode.F,
            actionText = "Change outfit",
            objectText = "Wardrobe",
            variant = "primary",
            children = { Lucy.Badge.new({ text = "VIP", variant = "secondary" }) },
        }),
    },
    Parent = parent,
})
```

## Restyle existing ProximityPrompts

If your game already uses Roblox `ProximityPrompt` instances with server
`Triggered` scripts, call `Lucy.Prompt.restyle(app)` once on the client. Every
`ProximityPrompt` switches to `Style = Custom` and is drawn with Lucy whenever
it shows:

```luau
Lucy.Prompt.restyle(app, {
    variant = "overlay",
    filter = function(raw)
        return not shouldHide(raw)
    end,
})
```

Pass an optional `filter(raw)` function to skip drawing specific prompts on the client (for
example, hiding a vehicle's seat prompts while already seated) without changing `raw.Enabled`
or `raw.Style`.

To restyle one prompt on its own, call `local prompt, stop = Lucy.Prompt.restyleOne(app, proximityPrompt, options)`.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `target` | BasePart, Attachment or Model | | | Object in the world to attach to |
| `action` | string | `""` | yes | Action name on `app.actions` |
| `keyboard` | KeyCode or string | `""` | yes | Keyboard key when `action` is empty |
| `gamepad` | KeyCode or string | `""` | yes | Gamepad button when `action` is empty |
| `touch` | string | `""` | yes | Touch label (`"Hold"` or `"Tap"` by default) |
| `actionText` | string | `"Interact"` | yes | Main verb shown in the prompt |
| `objectText` | string | `""` | yes | Smaller heading above `actionText` |
| `distance` | number | `10` | yes | Activation distance in studs |
| `hysteresis` | number | `0.5` | | Extra studs before leaving range |
| `lineOfSight` | boolean | `false` | | Require clear line of sight |
| `hold` | number | `0` | yes | Seconds to hold (`0` for instant trigger) |
| `exclusive` | boolean | `true` | | Only the nearest prompt per action is active |
| `showWhenInactive` | boolean | `false` | | Keep inactive prompts visible and dimmed |
| `enabled` | boolean | `true` | yes | Enable or disable the prompt |
| `side` | string | `"top"` | yes | `top`, `bottom`, `left` or `right` |
| `variant` | string | `"default"` | yes | `default`, `inverse`, `primary`, `secondary`, `outline`, `destructive`, `overlay` or registered |
| `size` | string | `"md"` | yes | `sm`, `md` or `lg` |
| `border`, `fill`, `transparency`, `radius` | | | | Visual overrides, same as `Tooltip` |
| `children` / `content` | | | | Extra components inside the prompt row |
| `onTrigger` | function | | | Called with `(prompt)` when triggered |
| `onHoldBegin` | function | | | Called with `(prompt)` when holding starts |
| `onHoldEnd` | function | | | Called with `(prompt, completed)` when holding stops |

It also takes the [props every component takes](index.md#using-a-component).

## Methods, events and parts

- `prompt:trigger()`, `prompt:beginHold()`, `prompt:endHold()`, `prompt:check()`
- `prompt.active()`, `prompt.inRange()`, `prompt.holding()`, `prompt.progress()`: tracked getters
- `prompt.Triggered`, `prompt.HoldBegan`, `prompt.HoldEnded`: signals
- `prompt.body`, `prompt.kbd`, `prompt.objectLabel`, `prompt.actionLabel`, `prompt.progressRing`, `prompt.progressBar`, `prompt.stroke`

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Prompt")`.
