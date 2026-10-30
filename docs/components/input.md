---
title: Input
description: A text field on one line.
---

# Input

A text field on one line, for names, codes and search. Its height grows on
touch and console, and a focus ring shows while the player types in it.

```lua
Lucy.Input.new({
    id = "playerName",
    placeholder = "Display name",
    onSubmit = function(name)
        setDisplayName(name)
    end,
    Parent = form,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `value` | string | `""` | yes | The text in the field |
| `placeholder` | string | `""` | yes | Grey text shown while the field is empty |
| `disabled` | boolean | `false` | yes | Greys it out and stops typing |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `width` | UDim | fills the parent | | How wide the field is |
| `onChange` | function | | | Called with `(value, handle)` as the text changes |
| `onSubmit` | function | | | Called with `(value, handle)` on Enter or the gamepad confirm button |

It also takes the [props every component takes](index.md#using-a-component).

## Methods

| Name | What it does |
|---|---|
| `input:focus()` | Puts the cursor in the field |

## Examples

Read the value by id:

```lua
local name = app.state:get("ui.playerName.value")
```

Keep a ref and the field in step:

```lua
local search = Lucy.ref("")

Lucy.Input.new({ placeholder = "Search items", value = search, Parent = shop })

Lucy.watch(search, function(text)
    filterItems(text)
end)
```

A fixed width:

```lua
Lucy.Input.new({ placeholder = "Code", width = UDim.new(0, 160), Parent = row })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Input")`.
