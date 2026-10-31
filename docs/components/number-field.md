---
title: Number Field
description: A number with minus and plus buttons, typed or stepped.
---

# Number Field

A number in a field, with a minus button before it and a plus button after it,
for counts and amounts: players in a lobby, rounds, items to buy. Press the
buttons, or hold them to keep going faster, or type a number. On keyboard and
gamepad the field is one stop: left and right change the number, like a
slider, and the confirm button starts typing.

```luau
Lucy.NumberField.new({
    value = 4,
    min = 1,
    max = 16,
    onValueCommit = function(players)
        lobby:setMaxPlayers(players)
    end,
    Parent = settings,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `value` | number | `0` | yes | The current number |
| `min` | number | no limit | yes | The lowest number |
| `max` | number | no limit | yes | The highest number |
| `step` | number | `1` | yes | How much the buttons and arrows change it; typed numbers snap to it |
| `placeholder` | string | `""` | yes | Grey text shown while the field is empty |
| `disabled` | boolean | `false` | yes | Greys it out and ignores input |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `format` | function | | | Turns the number into the shown text; whole numbers have no point by default |
| `width` | UDim | fills the parent | | How wide the whole field is, buttons included |
| `onValueChange` | function | | | Called with `(value, handle)` on every change, while a button is held too |
| `onValueCommit` | function | | | Called with `(value, handle)` once per press, held arrow or typed number that changed it |

It also takes the [props every component takes](index.md#using-a-component).

A typed number counts when the player presses Enter or leaves the field. It is
snapped to the step and kept between `min` and `max`; anything that is not a
number puts the old value back. Steps count from `min` when there is one, from
zero when not. A button turns grey at the end it moves towards.

The buttons draw the `lucy:minus` and `lucy:plus` icons. To use your own, see
[Icons Lucy draws](../guide/icons.md#icons-lucy-draws).

## Methods

| Name | What it does |
|---|---|
| `field:setValue(value)` | Sets the number, snapped to the step and kept in range |

## Examples

Keep a setting in app state and save it once the player has picked:

```luau
local rounds = app.state:ref("settings.rounds")

Lucy.NumberField.new({
    value = rounds,
    min = 1,
    max = 10,
    onValueCommit = function(value)
        remotes.SaveSetting:FireServer("rounds", value)
    end,
    Parent = settings,
})
```

A speed in quarter steps, shown with a suffix:

```luau
Lucy.NumberField.new({
    value = 1,
    min = 0.25,
    max = 4,
    step = 0.25,
    width = UDim.new(0, 200),
    format = function(value)
        return string.format("%.2fx", value)
    end,
    Parent = settings,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("NumberField")`.
