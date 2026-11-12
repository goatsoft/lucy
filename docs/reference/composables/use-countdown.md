---
title: useCountdown
description: Synchronised countdown of whole seconds remaining until a timestamp.
order: 10
---

# useCountdown

`Lucy.useCountdown` counts whole seconds left until `endsAt` using
`workspace:GetServerTimeNow()`. Because every client reads server time, all
players see the same second tick down without the server sending updates every
second.

## Usage

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/reference-composables-use-countdown-light.webp" alt="useCountdown example" loading="lazy"><img class="example-dark" src="/images/examples/reference-composables-use-countdown-dark.webp" alt="useCountdown example" loading="lazy"></figure>

```luau
local timer = Lucy.useCountdown(setEndsAt)

Lucy.Text.new({
    text = function()
        return `{timer.remaining()}s left in the set`
    end,
})
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `endsAt` | `MaybeRef<number?>` | required | Target timestamp in `workspace:GetServerTimeNow()` seconds |

### Returns

| Name | Type | What it is |
|---|---|---|
| `remaining()` | `() -> number` | Whole seconds left until `endsAt`, never below 0. Updates once per second |
| `done()` | `() -> boolean` | `true` once `remaining()` reaches 0 |

If `endsAt` is `nil`, `remaining` is `0` and `done` is `false`. When the target
timestamp changes, the countdown adjusts immediately.

## Example: Club Lucy DJ set round timer

Show how long remains in DJ Lucy's current set:

```luau
local currentSetEndsAt = app.state:ref("booth.roundEndsAt")
local countdown = Lucy.useCountdown(currentSetEndsAt)

Lucy.Text.new({
    text = function()
        if countdown.done() then
            return "Set finished! Next DJ up..."
        end
        return `{countdown.remaining()} seconds remaining in set`
    end,
    Parent = hud,
})
```
