<!-- Made by scripts/skills.ts from docs/components/pressable.md. Edit the doc, not this file. -->
# Pressable

A surface the player can click, tap or select with a gamepad, holding whatever
you put in it: an icon, a name, a price, a whole card. Use it where a Button's
single line of text is not enough, such as shop items, song rows or vote cards.

The whole card is the button, so don't put buttons inside it. For a card that
holds its own buttons, such as a shop item with a Buy button, use a
[Panel](panel.md).

```luau
Lucy.Pressable.new({
    size = UDim2.fromOffset(160, 200),
    padding = "Space3",
    onClick = function()
        buy(item)
    end,
    children = {
        Lucy.Stack.new({
            gap = "Space2",
            children = {
                Lucy.Text.new({ text = item.name, variant = "large" }),
                Lucy.Text.new({ text = `{item.price} coins`, variant = "muted" }),
            },
        }),
    },
    Parent = grid,
})
```

It lays out nothing itself. Put a [Stack](stack.md) inside to arrange its content.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `selected` | boolean | `false` | yes | Shows it as picked, for tabs, filters and chosen cards |
| `disabled` | boolean | `false` | yes | Ignores clicks and leaves the gamepad selection |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `children` | table | | | Instances or handles to put in it |
| `size` | UDim2 | fits its content | | Its size |
| `padding` | spacing | none | | Space around the inside edge: a token such as `"Space3"`, or pixels |
| `onClick` | function | | | Called with the handle when it is clicked |

It also takes the [props every component takes](index.md#using-a-component).

## Methods and events

| Name | What it does |
|---|---|
| `pressable.Activated` | A signal that fires on every click |
| `pressable:click()` | Runs a click from code, as if the player clicked |

Clicks work the same as on a [Button](button.md): ignored while disabled, and
within 50 ms of the last one.

## Looks

It has no background until the pointer is over it, then shows the accent colour.
Pressing it shows the muted colour. A selected one keeps the accent background
and gets a ring around it. Gamepad and keyboard focus show the usual focus ring.

## Examples

A row of genre cards where one is picked at a time:

```luau
local picked = Lucy.ref("House")

for _, genre in { "House", "Techno", "Hip hop" } do
    Lucy.Pressable.new({
        size = UDim2.fromOffset(140, 96),
        padding = "Space4",
        selected = function() return picked() == genre end,
        onClick = function() picked(genre) end,
        children = { Lucy.Text.new({ text = genre, variant = "large" }) },
        Parent = row,
    })
end
```

A locked shop item that cannot be clicked:

```luau
Lucy.Pressable.new({
    disabled = function() return not owned(item.id) end,
    children = { icon, name },
    Parent = shop,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Pressable")`.
