<!-- Made by scripts/skills.ts from docs/components/radio-group.md. Edit the doc, not this file. -->
# Radio Group

A list of options where the player picks exactly one, for forms and settings:
difficulty, server region, a report reason. Each row is the hit area, and the
circle grows on touch and console.

```luau
Lucy.RadioGroup.new({
    items = {
        { value = "house", label = "House" },
        { value = "disco", label = "Disco" },
        { value = "techno", label = "Techno" },
        { value = "pop", label = "Pop", disabled = true },
    },
    value = "house",
    onValueChange = function(genre)
        app.toast(`Next up: {genre}`)
    end,
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `items` | table | | | The options, in order (see below) |
| `value` | any | `false` | yes | The picked value, `false` when nothing is picked yet |
| `orientation` | string | `"vertical"` | | `vertical` for a column, `horizontal` for a row |
| `gap` | spacing | `"Space2"` | | Space between options |
| `size` | `"sm"` \| `"md"` \| `"lg"` \| `"xl"` | `"md"` | yes | The circle, the label's text and the row's height, as a Switch or Button of the same size |
| `disabled` | boolean | `false` | yes | Greys every option out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onValueChange` | function | | | Called with `(value, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

An option is a value (shown as its text) or a table:

| Field | What it does |
|---|---|
| `value` | What the option stands for. Required |
| `label` | Its text. Defaults to the value. `text` works too |
| `children` | Anything after the label in the option's [slot](slot.md), such as a badge. They take the label's look and fade when disabled. With children and no label, the option shows no text |
| `disabled` | Greys this option out |

Once something is picked, the player can pick another option but cannot clear
it. When the player picks one, it reports `select` with that value for
[useUiSound](../reference/composables/use-ui-sound.md).

`handle.items` holds one table per option, in order, with its `root`, `circle`,
`dot` and `label`.

## Methods

| Name | What it does |
|---|---|
| `group:select(value)` | Picks the option, as if the player clicked it |

## Examples

Keep the choice in app state:

```luau
Lucy.RadioGroup.new({
    items = { "House", "Disco", "Hip hop", "Techno" },
    value = app.state:ref("booth.genre"),
    Parent = booth,
})
```

A radio group comes in the same sizes as the other controls, and each size is as tall as a
Switch or Button of that size, so they line up in a settings panel. Go a size up on a phone,
where the options need to be easy to tap:

```luau
Lucy.Stack.new({
    gap = "Space3",
    children = {
        Lucy.Switch.new({ label = "Crowd sounds", size = "lg", checked = true }),
        Lucy.Text.new({ text = "Who can ask you to dance", variant = "large" }),
        Lucy.RadioGroup.new({
            items = { "Everyone", "Crew only", "Nobody" },
            value = "Crew only",
            orientation = "horizontal",
            size = "lg",
        }),
    },
    Parent = parent,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("RadioGroup")`.
