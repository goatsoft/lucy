<!-- Made by scripts/skills.ts from docs/components/button.md. Edit the doc, not this file. -->
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
| `text` | string | `"Button"`, or `""` with an icon | yes | The label |
| `icon` | string | | yes | An [icon](icon.md) name drawn before the text, in the text's colour. See below |
| `variant` | string | `"default"` | yes | `default`, `destructive`, `outline`, `secondary`, `ghost` or `link` |
| `size` | string | `"md"` | yes | `sm`, `md`, `lg` or `icon` |
| `disabled` | boolean | `false` | yes | Greys the button out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides the button |
| `hint` | table | | | A key to show after the text: the props of a [Kbd](kbd.md). See below |
| `onClick` | function | | | Called with the handle when the button is clicked |

It also takes the [props every component takes](index.md#using-a-component).

## Methods and events

| Name | What it does |
|---|---|
| `button.Activated` | A signal that fires on every click |
| `button:click()` | Runs a click from code, as if the player clicked |

A disabled button ignores clicks, and a gamepad skips over it. Clicks within
50 ms of the last one are ignored too, so one press of Enter never counts twice.

## Icons

`icon` draws an icon before the text, coloured like the text in every variant.
With no text, the icon shows alone; use `size = "icon"` for a square button.

```lua
Lucy.Button.new({ text = "Settings", icon = "lucide:settings", variant = "outline", Parent = bar })
Lucy.Button.new({ icon = "lucide:settings", size = "icon", variant = "ghost", Parent = bar })
```

`button.icon` is the [Icon](icon.md), and `button:set("icon", name)` changes it.
A button made without `icon` has no icon to change. The name has to be
registered first, like any icon; see [Icons](https://lucy.goatsoft.io/docs/guide/icons/).

## Key hints

`hint` puts a key cap after the text, showing the right key for the player's
input: the keyboard key, the controller's button, and nothing on touch.

```lua
Lucy.Button.new({
    text = "Join",
    hint = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.DPadUp },
    onClick = join,
    Parent = hud,
})
```

It takes the same fields as [Kbd](kbd.md): `keyboard`, `gamepad` and `touch`,
each a value, a ref or a getter. The hint only shows the key; binding the key
to the button's action is up to your game.

With a hint, the text sits in `button.label` and the key cap is `button.hint`
(a Kbd handle). Both follow the button's variant, size and disabled state.
Face buttons keep their controller colours on any button; pass
`variant = "mono"` in the hint to draw them in the button's text colour.
Without one, the button is a single TextButton as usual.

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

A close button, the one dialogs and sheets put in their top right corner: a
ghost icon button with a large ×. It takes the same props as `Button.new`.

```lua
local close = Lucy.Button.close({ onClick = hidePanel })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Button")`.
