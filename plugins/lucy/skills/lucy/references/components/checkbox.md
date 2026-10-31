<!-- Made by scripts/skills.ts from docs/components/checkbox.md. Edit the doc, not this file. -->
# Checkbox

A box the player can check and uncheck, with an optional label. The whole row
is the hit area, and it grows on touch and console so it is easy to hit with a
thumb or a gamepad.

```luau
Lucy.Stack.new({
    gap = "Space2",
    children = {
        Lucy.Checkbox.new({
            label = "Mute music",
            onCheckedChange = function(checked)
                app.state:set("settings.music", if checked then 0 else 80)
            end,
        }),
        Lucy.Checkbox.new({ label = "Light show", checked = true }),
        Lucy.Checkbox.new({ label = "Show my dance combo", checked = true }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `checked` | boolean | `false` | yes | Whether the box is checked |
| `label` | string | `""` | yes | Text beside the box |
| `disabled` | boolean | `false` | yes | Greys it out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onCheckedChange` | function | | | Called with `(checked, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

## Methods

| Name | What it does |
|---|---|
| `checkbox:toggle()` | Checks it if unchecked, unchecks it if checked |

## Examples

Keep a ref and a checkbox in step. Writing the ref checks the box, and checking
the box writes the ref:

```luau
local muted = Lucy.ref(false)

Lucy.Checkbox.new({ label = "Mute the crowd", checked = muted, Parent = settings })

muted(true) -- the box is now checked
```

Read it from app state by id:

```luau
Lucy.Checkbox.new({ id = "rules", label = "I agree to the club rules", Parent = welcome })

if app.state:get("ui.rules.checked") then
    enterLobby()
end
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Checkbox")`.
