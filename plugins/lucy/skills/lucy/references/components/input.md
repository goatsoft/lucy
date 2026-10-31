<!-- Made by scripts/skills.ts from docs/components/input.md. Edit the doc, not this file. -->
# Input

A text field for names, codes, search and chat, on one line or several. Its
height grows on touch and console, and a focus ring shows while the player
types in it. It can also limit what the player types: a number only, or a
maximum length.

```luau
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
| `maxLength` | number | | | The most characters the player can type |
| `numeric` | boolean | `false` | | Only digits, a minus at the start and one point can be typed |
| `multiline` | boolean | `false` | | Wraps text over several lines; Enter starts a new line |
| `rows` | number | `3` | | How many lines tall a multiline field is |
| `onChange` | function | | | Called with `(value, handle)` as the text changes |
| `onSubmit` | function | | | Called with `(value, handle)` on Enter or the gamepad confirm button (not in a multiline field) |

It also takes the [props every component takes](index.md#using-a-component).

`maxLength` and `numeric` apply to what the player types. The value is always
a string.

## Methods

| Name | What it does |
|---|---|
| `input:focus()` | Puts the cursor in the field |

## Examples

Read the value by id:

```luau
local name = app.state:get("ui.playerName.value")
```

Keep a ref and the field in step:

```luau
local search = Lucy.ref("")

Lucy.Input.new({ placeholder = "Search items", value = search, Parent = shop })

-- The items whose name has the search text, for a list's `data`
local shown = Lucy.computed(function()
    local text = string.lower(search())
    local found = {}
    for _, item in items do
        if string.find(string.lower(item.name), text, 1, true) then
            table.insert(found, item)
        end
    end
    return found
end)
```

A message box that holds 200 characters:

```luau
Lucy.Input.new({
    placeholder = "Message",
    multiline = true,
    rows = 4,
    maxLength = 200,
    Parent = form,
})
```

A code of six digits:

```luau
Lucy.Input.new({ placeholder = "Code", numeric = true, maxLength = 6, Parent = form })
```

A fixed width:

```luau
Lucy.Input.new({ placeholder = "Code", width = UDim.new(0, 160), Parent = row })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Input")`.
