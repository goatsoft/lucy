---
title: Button
description: A button, in six variants and four sizes.
---

# Button

A button the player can click, tap or select with a gamepad. It comes in six
variants and four sizes.

```lua
Lucy.Button.new({
    text = "Play",
    onClick = function()
        app.scenes:goTo("Game")
    end,
    Parent = frame,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `text` | string | `"Button"` | yes | The label |
| `variant` | string | `"default"` | yes | `default`, `destructive`, `outline`, `secondary`, `ghost` or `link` |
| `size` | string | `"md"` | yes | `sm`, `md`, `lg` or `icon` |
| `disabled` | boolean | `false` | yes | Greys the button out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides the button |
| `onClick` | function | | | Called with the handle when the button is clicked |

It also takes the [props every component takes](index.md#using-a-component).

## Methods and events

| Name | What it does |
|---|---|
| `button.Activated` | A signal that fires on every click |
| `button:click()` | Runs a click from code, as if the player clicked |

A disabled button ignores clicks. Clicks within 50 ms of the last one are ignored
too, so one press of Enter never counts twice.

## Examples

Every variant:

```lua
for _, variant in { "default", "secondary", "outline", "ghost", "destructive", "link" } do
    Lucy.Button.new({ text = variant, variant = variant, size = "sm", Parent = row })
end
```

A buy button that follows the player's coins and turns off while a purchase runs:

```lua
local coins = app.state:ref("player.coins")
local buying = Lucy.ref(false)

Lucy.Button.new({
    text = function() return `Buy for 100 ({coins()} left)` end,
    disabled = function() return buying() or coins() < 100 end,
    onClick = function()
        buying(true)
        buyItem()
        buying(false)
    end,
    Parent = shop,
})
```

Disable a button from anywhere by its id:

```lua
Lucy.Button.new({ id = "play", text = "Play", Parent = frame })

app.state:set("ui.play.disabled", true)
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Button")`.
