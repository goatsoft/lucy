<!-- Made by scripts/skills.ts from docs/components/button.md. Edit the doc, not this file. -->
# Button

A button the player can click, tap or select with a gamepad. It comes in six
variants and four sizes.

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space2",
    children = {
        Lucy.Button.new({
            text = "Hit the floor",
            icon = "lucide-extended:music-filled",
            onClick = function()
                app.toast("See you on the dance floor")
            end,
        }),
        Lucy.Button.new({ text = "Emote Shop", icon = "lucide-extended:shopping-bag-filled", variant = "secondary" }),
        Lucy.Button.new({ text = "Settings", variant = "outline" }),
    },
    Parent = parent,
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

```luau
Lucy.Button.new({ text = "Queue", icon = "lucide-extended:list-music-filled", variant = "outline", Parent = bar })
Lucy.Button.new({ icon = "lucide-extended:settings-filled", size = "icon", variant = "ghost", Parent = bar })
```

`button.icon` is the [Icon](icon.md), and `button:set("icon", name)` changes it.
A button made without `icon` has no icon to change. The name has to be
registered first, like any icon; see [Icons](../../../lucy-icons/references/guide/icons.md).

## Key hints

`hint` puts a key cap after the text, showing the right key for the player's
input: the keyboard key, the controller's button, and nothing on touch.

```luau
Lucy.Button.new({
    text = "Dance",
    hint = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.ButtonX },
    onClick = dance,
    Parent = hud,
})
```

A hint needs text beside it: an icon-only button (`size = "icon"`) is a fixed
square with no room for the key cap, so give it `text` when it has a hint.

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

```luau
for _, variant in { "default", "secondary", "outline", "ghost", "destructive", "link" } do
    Lucy.Button.new({ text = variant, variant = variant, size = "sm", Parent = row })
end
```

A buy button for an emote that follows the player's coins and turns off while
the purchase runs (`buyEmote` is your game's own function):

```luau
local coins = app.state:ref("player.coins")
local buying = Lucy.ref(false)

Lucy.Button.new({
    text = function() return `Buy Moonwalk for 300 ({coins()} left)` end,
    disabled = function() return buying() or coins() < 300 end,
    onClick = function()
        buying(true)
        buyEmote("Moonwalk")
        buying(false)
    end,
    Parent = shop,
})
```

Disable a button from anywhere by its id:

```luau
Lucy.Button.new({ id = "startSet", text = "Start your set", Parent = booth })

app.state:set("ui.startSet.disabled", true) -- someone else is on the decks
```

A close button, the one dialogs and sheets put in their top right corner: a
ghost icon button with a large ×. It takes the same props as `Button.new`.

```luau
local close = Lucy.Button.close({ onClick = closeQueue })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Button")`.
