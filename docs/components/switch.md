---
title: Switch
description: An on and off switch, with an optional label.
---

# Switch

An on and off switch with an optional label, for settings. The whole row is
the hit area, and the switch grows on touch and console. It comes in the same
sizes as the other controls, and a row is as tall as a Button of its size, so
a switch lines up with buttons and toggles beside it.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-switch-light.webp" alt="Switch example" loading="lazy"><img class="example-dark" src="/images/examples/components-switch-dark.webp" alt="Switch example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space3",
    children = {
        Lucy.Switch.new({
            label = "Club lights",
            checked = true,
            onCheckedChange = function(on)
                app.toast(if on then "Lights up" else "Lights down")
            end,
        }),
        Lucy.Switch.new({ label = "Crowd cheers", checked = true }),
        Lucy.Switch.new({ label = "Show dance names" }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `checked` | boolean | `false` | yes | Whether it is on |
| `label` | string | `""` | yes | Text beside the switch |
| `children` | table | | | Anything after the label in its [slot](slot.md), such as a "NEW" badge. They take the label's look and fade when disabled |
| `disabled` | boolean | `false` | yes | Greys it out and ignores clicks |
| `size` | `"sm"` \| `"md"` \| `"lg"` \| `"xl"` | `"md"` | yes | The track, the label's text and the row's height, as a Button of the same size |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onCheckedChange` | function | | | Called with `(checked, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

## Methods

| Name | What it does |
|---|---|
| `switch:toggle()` | Turns it on if off, off if on |

## Examples

Keep a setting in app state and the switch in step:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-switch-2-light.webp" alt="Switch example" loading="lazy"><img class="example-dark" src="/images/examples/components-switch-2-dark.webp" alt="Switch example" loading="lazy"></figure>

```luau
local lights = app.state:ref("settings.lights")

Lucy.Switch.new({ label = "Club lights", checked = lights, Parent = settings })

-- Elsewhere, game code reads the same value.
Lucy.watch(lights, function(on)
    discoBall.Enabled = on
end)
```

Grey a switch out while something loads:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-switch-3-light.webp" alt="Switch example" loading="lazy"><img class="example-dark" src="/images/examples/components-switch-3-dark.webp" alt="Switch example" loading="lazy"></figure>

```luau
local loading = Lucy.ref(true)

Lucy.Switch.new({ label = "Light show", disabled = loading, Parent = settings })
```

Pick a size to sit beside controls of that size, or to be easy to hit on a busy screen:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-switch-4-light.webp" alt="Switch example" loading="lazy"><img class="example-dark" src="/images/examples/components-switch-4-dark.webp" alt="Switch example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space3",
    children = {
        Lucy.Switch.new({ label = "Small", size = "sm", checked = true }),
        Lucy.Switch.new({ label = "Medium", size = "md", checked = true }),
        Lucy.Switch.new({ label = "Large", size = "lg", checked = true }),
        Lucy.Switch.new({ label = "Extra large", size = "xl", checked = true }),
    },
    Parent = parent,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Switch")`.
