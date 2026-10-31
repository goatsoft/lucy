---
title: Select
description: A button that opens a list of options to pick one from.
---

# Select

A button that opens a list of options to pick one from: a server region, a sort
order, a game mode. It shows the option picked, or a placeholder until there is
one.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-select-light.webp" alt="Select example" loading="lazy"><img class="example-dark" src="/images/examples/components-select-dark.webp" alt="Select example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space2",
    children = {
        Lucy.Text.new({ text = "Next set", variant = "label" }),
        Lucy.Select.new({
            id = "genre",
            placeholder = "Genre",
            value = "house",
            items = {
                { value = "house", label = "House" },
                { value = "disco", label = "Disco" },
                "Techno",
            },
            onValueChange = function(value)
                app.toast(`Next set: {value}`)
            end,
        }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `items` | table | | | The options, see [Items](#items) |
| `value` | any | `false` | yes | The value picked, or `false` for none yet. With `multiple`, an array |
| `type` | string | `"default"` | | `default` or `check`, see [Types](#types) |
| `multiple` | boolean | `false` | | Lets the player pick several (a `check` select) |
| `placeholder` | string | `"Select"` | yes | Shown until something is picked |
| `open` | boolean | `false` | yes | Whether the list is open |
| `disabled` | boolean | `false` | yes | Stops the player opening it, and closes it |
| `size` | UDim2 | full width, control height | | The button's size |
| `side` | string | `"bottom"` | | `bottom` or `top`: where the list opens. It flips when the other side has more room |
| `align` | string | `"start"` | | `start`, `center` or `end`: how the list lines up with the button |
| `onValueChange` | function | | | Called with `(value, handle)` when the value changes |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

### Items

An item is a value, shown as its text, or a table with `value`, and optionally
`label` (or `text`; both work) and `disabled`. A disabled option shows faded and cannot be picked.

## Types

- **`default`:** the picked option is highlighted in the list.
- **`check`:** a tick in front of the picked option.

With `multiple = true` the select is a `check` select where the player can
pick several. Each press ticks or unticks an option and the list stays open.
The value is an array in the order of `items`, and the button shows the first
label and how many more, such as "Pop +2".

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-select-2-light.webp" alt="Select example" loading="lazy"><img class="example-dark" src="/images/examples/components-select-2-dark.webp" alt="Select example" loading="lazy"></figure>

```luau
Lucy.Select.new({
    multiple = true,
    placeholder = "Genres",
    items = { "Pop", "Hip hop", "House", "Techno" },
    onValueChange = function(genres)
        app.toast(`{#genres} genres in the mix`)
    end,
})
```

## How it opens

The list opens on the app's overlay layer, above everything opened before it:

- **Mouse and keyboard:** under the button (or above it when there is more room
  there), at least as wide as the button.
- **Gamepad:** the same, with the option already picked selected. When it
  closes, the button is selected again.
- **Touch:** a drawer from the bottom of the screen, where a thumb can reach it.
  It slides up (it just appears with reduced motion) and leaves room above a
  phone's home bar.

A long list scrolls inside the space it has. B, Backspace or a press outside
closes it without changing anything.

The button draws `lucy:chevron-down`, and a `check` select draws `lucy:check`.
To use your own, see [Icons Lucy draws](../guide/icons.md#icons-lucy-draws).

## Methods and events

| Name | What it does |
|---|---|
| `select:select(value)` | Picks `value` as if the player had, and closes the list. With `multiple`, ticks or unticks it |
| `select:open()` | Opens the list |
| `select:close()` | Closes the list |
| `select:toggle()` | Opens it if closed, closes it if open |
| `select.presentation()` | `"popup"` or `"drawer"`, for this opening |

When the player picks an option, it reports `select` with the value, for
[game sounds](../reference/composables.md).

## Examples

Read or change the value from anywhere by its id:

```luau
app.state:get("ui.genre.value")
app.state:set("ui.genre.value", "disco")
```

Keep it in step with a ref:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-select-3-light.webp" alt="Select example" loading="lazy"><img class="example-dark" src="/images/examples/components-select-3-dark.webp" alt="Select example" loading="lazy"></figure>

```luau
local sort = Lucy.ref("newest")
Lucy.Select.new({
    value = sort,
    items = {
        { value = "newest", label = "Newest" },
        { value = "popular", label = "Most played" },
    },
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Select")`.
