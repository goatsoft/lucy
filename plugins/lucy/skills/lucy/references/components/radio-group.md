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
| `disabled` | boolean | `false` | yes | Greys every option out and ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `onValueChange` | function | | | Called with `(value, handle)` when it changes |

It also takes the [props every component takes](index.md#using-a-component).

An option is a value (shown as its text) or a table:

| Field | What it does |
|---|---|
| `value` | What the option stands for. Required |
| `label` | Its text. Defaults to the value. `text` works too |
| `disabled` | Greys this option out |

Once something is picked, the player can pick another option but cannot clear
it. When the player picks one, it reports `select` with that value for
[useUiSound](../reference/composables.md#useuisound).

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

## Preview

In Studio, from the command bar: `Lucy.Preview.show("RadioGroup")`.
