---
title: Collapsible
description: A header that shows or hides what is under it.
---

# Collapsible

A header the player presses to show or hide what is under it: advanced
settings, the rules of a round, a long list they rarely need. For a set of
sections where opening one can close the others, use an [Accordion](accordion.md).

```lua
Lucy.Collapsible.new({
    text = "Advanced",
    content = function()
        return Lucy.Stack.new({
            gap = "Space2",
            children = {
                Lucy.Switch.new({ label = "Show ping" }),
                Lucy.Switch.new({ label = "Show frame rate" }),
            },
        })
    end,
    Parent = settingsPanel,
})
```

It fills the width of its parent. Opening and closing slide the height over a
short tween, and the chevron turns with it. Closed content is hidden, so
keyboard and gamepad focus skip it; when it is open, up and down move from the
header into the content and back.

## Variants

- `default`: a full width header with the chevron on the right and a line
  under the section.
- `details`: a compact header with the chevron before the text and the content
  indented under it, for a "show more" in the middle of other content.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `text` | string | `""` | yes | The header text |
| `content` | Instance, handle or function | | | What it shows and hides; a function is called once at mount |
| `open` | boolean | `false` | yes | Whether it is open |
| `variant` | string | `"default"` | yes | `default` or `details` |
| `disabled` | boolean | `false` | yes | Greys out the header and ignores presses |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onOpenChange` | function | | | Called with `(open, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

When the player opens or closes it, it reports `toggle` with the new open state
for [useUiSound](../reference/composables.md#useuisound).

## Methods

| Name | What it does |
|---|---|
| `collapsible:toggle()` | Opens it if closed, closes it if open, as if the player pressed the header |

To open or close it without reporting a press, set the state:
`collapsible:set("open", true)`.

## Examples

Keep it open across visits with app state:

```lua
Lucy.Collapsible.new({
    text = "Show the rules",
    variant = "details",
    open = app.state:ref("settings.rulesOpen"),
    content = rulesText,
    Parent = lobby,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Collapsible")`.
