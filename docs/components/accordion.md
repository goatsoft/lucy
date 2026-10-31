---
title: Accordion
description: Sections the player opens and closes, one or several at a time.
---

# Accordion

A stack of sections with a header each: a settings menu, a list of quests, the
help pages of a game. By default one section is open at a time, and pressing the
open one closes it. Each section is a [Collapsible](collapsible.md).

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-accordion-light.webp" alt="Accordion example" loading="lazy"><img class="example-dark" src="/images/examples/components-accordion-dark.webp" alt="Accordion example" loading="lazy"></figure>

```luau
Lucy.Accordion.new({
    value = "audio",
    items = {
        { value = "audio", text = "Music volume", content = function()
            return Lucy.Slider.new({ value = app.state:ref("settings.music"), showValue = true })
        end },
        { value = "lights", text = "Lights", content = function()
            return Lucy.Switch.new({ label = "Light show", checked = app.state:ref("settings.lights") })
        end },
        { value = "controls", text = "Controls", content = Lucy.Text.new({
            text = "E to dance, Q for the queue", variant = "muted",
        }) },
    },
    Parent = parent,
})
```

Each header is a focus stop. Up and down move between the headers, and into an
open section's content and back out. A, Enter or a click opens and closes a
section.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `items` | table | | | The sections: `{ value, text, content, disabled }` each |
| `type` | string | `"single"` | | `single`: one open at a time; `multiple`: any number. Set at mount |
| `value` | any | `false` | yes | `single`: the open section's value, or `false`. `multiple`: a list of values |
| `variant` | string | `"default"` | yes | The sections' look: `default` or `details` (see [Collapsible](collapsible.md#variants)) |
| `disabled` | boolean | `false` | yes | Greys out every header and ignores presses |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onValueChange` | function | | | Called with `(value, handle)` when it changes |

An item's `content` is an Instance, a handle, or a function returning either,
built once at mount. An item with `disabled = true` can't be opened by the
player.

It also takes the [props every component takes](index.md#using-a-component).

When the player opens or closes a section, that section reports `toggle` with
its open state for [useUiSound](../reference/composables.md#useuisound).

## Methods

| Name | What it does |
|---|---|
| `accordion:toggle(value)` | Opens or closes that section, as if the player pressed its header |

`accordion.sections[value]` is the Collapsible for each section. To open
sections without reporting a press, set the state:
`accordion:set("value", "video")`, or a list with `type = "multiple"`.

## Examples

Let the player keep several sections of the Queue open, starting with two:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-accordion-2-light.webp" alt="Accordion example" loading="lazy"><img class="example-dark" src="/images/examples/components-accordion-2-dark.webp" alt="Accordion example" loading="lazy"></figure>

```luau
Lucy.Accordion.new({
    type = "multiple",
    value = { "upNext", "requests" },
    items = {
        { value = "upNext", text = "Up next", content = upNextList },
        { value = "requests", text = "Requests", content = requestList },
        { value = "party", text = "Party night", content = partyList, disabled = not partyLive },
    },
    Parent = queuePanel,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Accordion")`.
