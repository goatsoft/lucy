<!-- Made by scripts/skills.ts from docs/components/switch.md. Edit the doc, not this file. -->
# Switch

An on and off switch with an optional label, for settings. The whole row is
the hit area, and the switch grows on touch and console.

```luau
Lucy.Switch.new({
    label = "Music",
    checked = true,
    onCheckedChange = function(on)
        music.Volume = if on then 0.5 else 0
    end,
    Parent = settings,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `checked` | boolean | `false` | yes | Whether it is on |
| `label` | string | `""` | yes | Text beside the switch |
| `disabled` | boolean | `false` | yes | Greys it out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onCheckedChange` | function | | | Called with `(checked, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

## Methods

| Name | What it does |
|---|---|
| `switch:toggle()` | Turns it on if off, off if on |

## Examples

Keep a setting in app state and the switch in step:

```luau
local music = app.state:ref("settings.music")

Lucy.Switch.new({ label = "Music", checked = music, Parent = settings })

-- Elsewhere, game code reads the same value.
Lucy.watch(music, function(on)
    soundtrack.Playing = on
end)
```

Grey a switch out while something loads:

```luau
local loading = Lucy.ref(true)

Lucy.Switch.new({ label = "Shadows", disabled = loading, Parent = settings })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Switch")`.
