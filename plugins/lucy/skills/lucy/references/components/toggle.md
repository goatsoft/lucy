<!-- Made by scripts/skills.ts from docs/components/toggle.md. Edit the doc, not this file. -->
# Toggle

A button that stays pressed until it is clicked again: mute, a filter, show
the map. For one choice out of several, use a [Toggle Group](toggle-group.md).

```luau
Lucy.Toggle.new({
    text = "Voice chat",
    pressed = true,
    onPressedChange = function(on)
        voice.Enabled = on
    end,
    Parent = toolbar,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `text` | string | `""` | yes | The text on it |
| `pressed` | boolean | `false` | yes | Whether it is on |
| `variant` | string | `"default"` | yes | `default` or `outline` |
| `size` | string | `"md"` | yes | `sm`, `md` or `lg` |
| `disabled` | boolean | `false` | yes | Greys it out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `children` | table | | | Shown in place of the text, such as an icon |
| `onPressedChange` | function | | | Called with `(pressed, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

When the player turns it on or off, it reports `toggle` with the new value for
[useUiSound](../reference/composables.md#useuisound).

## Methods

| Name | What it does |
|---|---|
| `toggle:toggle()` | Turns it on if off, off if on, as if the player clicked it |

## Examples

Keep it in step with a setting:

```luau
local showMap = app.state:ref("settings.map")

Lucy.Toggle.new({ text = "Map", pressed = showMap, variant = "outline", Parent = hud })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Toggle")`.
