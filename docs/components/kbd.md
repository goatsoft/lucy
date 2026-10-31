---
title: Kbd
description: The key to press, for the player's keyboard or controller.
---

# Kbd

Shows which key to press, for the input the player is using right now: the
key on a keyboard, the button on a controller, and nothing on a phone. It
changes the moment the player picks up a controller or goes back to the mouse.

```luau
Lucy.Kbd.new({
    keyboard = Enum.KeyCode.E,
    gamepad = Enum.KeyCode.DPadUp,
    Parent = row,
})
```

Controller buttons show the engine's own picture for the player's controller,
so PlayStation players see PlayStation buttons. The face buttons are in their
controller's colours: on Xbox A is green, B red, X blue and Y yellow; on
PlayStation the cross is blue, the circle red, the square pink and the triangle
green. Other buttons, and the `mono` variant, use the text colour. To put a key on a button, use
the Button's [`hint`](button.md#key-hints) prop.

Kbd only shows the key. Binding the key to an action is up to your game.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `keyboard` | KeyCode or string | | yes | Shown for keyboard and mouse |
| `gamepad` | KeyCode or string | | yes | Shown for a controller, as its picture when it has one |
| `touch` | string | | yes | Shown on touch, such as `"Tap"`. Without it, nothing shows on touch |
| `variant` | string | `"color"` | yes | `color` gives face buttons their controller colours; `mono` draws every button in the text colour |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

It hides itself when it has no key for the current input. Text can stand in
for any key, such as `gamepad = "Hold A"`.

Keyboard keys are named for the player's keyboard layout. Keys with no letter
get short names: `Esc`, `Enter`, `Space`, `Tab`, `Shift`, `Ctrl`, `Alt`, `Up`,
`Down`, `Left` and `Right`.

Its parts are on the handle: `kbd.text` is the label and `kbd.glyph` the
controller picture. `Lucy.Kbd.label(key)` gives a key's text, and
`Lucy.Kbd.glyph(keyCode)` its controller picture. `Lucy.Kbd.platform()` says
whether the player's controller is `"xbox"` or `"playstation"` style.

## Examples

A hint beside a line of text:

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space2",
    align = "center",
    children = {
        Lucy.Kbd.new({ keyboard = Enum.KeyCode.Escape, gamepad = Enum.KeyCode.ButtonB }),
        Lucy.Text.new({ text = "Close", variant = "muted", autoWidth = true }),
    },
    Parent = footer,
})
```

A key that changes with game state:

```luau
local key = Lucy.ref(Enum.KeyCode.One)

Lucy.Kbd.new({ keyboard = key, Parent = slot })
key(Enum.KeyCode.Two)
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Kbd")`. Its `input`
control switches between keyboard, gamepad and touch.
