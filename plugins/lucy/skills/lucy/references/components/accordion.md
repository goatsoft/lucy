<!-- Made by scripts/skills.ts from docs/components/accordion.md. Edit the doc, not this file. -->
# Accordion

A stack of sections with a header each: a settings menu, a list of quests, the
help pages of a game. By default one section is open at a time, and pressing the
open one closes it. Each section is a [Collapsible](collapsible.md).

```lua
Lucy.Accordion.new({
    value = "audio",
    items = {
        { value = "audio", text = "Audio", content = audioSettings },
        { value = "video", text = "Video", content = videoSettings },
        { value = "controls", text = "Controls", content = function()
            return buildControls()
        end },
    },
    Parent = settingsPanel,
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

Let the player keep several sections open, starting with two:

```lua
Lucy.Accordion.new({
    type = "multiple",
    value = { "daily", "weekly" },
    items = {
        { value = "daily", text = "Daily quests", content = dailyList },
        { value = "weekly", text = "Weekly quests", content = weeklyList },
        { value = "event", text = "Event", content = eventList, disabled = not eventLive },
    },
    Parent = questPanel,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Accordion")`.
