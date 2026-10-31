<!-- Made by scripts/skills.ts from docs/components/spinner.md. Edit the doc, not this file. -->
# Spinner

A small ring that turns while something loads: finding a server, saving, or
waiting on a purchase.

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space3",
    align = "center",
    children = {
        Lucy.Spinner.new({ variant = "primary" }),
        Lucy.Text.new({ text = "DJ Lucy is mixing the next track", autoWidth = true }),
    },
    Parent = parent,
})
```

It only turns while it is visible, so a hidden spinner costs nothing. When the
player asks for reduced motion, it stays still and pulses instead.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `size` | string | `"md"` | yes | `sm` (16 pixels), `md` (24) or `lg` (32) |
| `variant` | string | `"default"` | yes | The ring's colour: `default` (the text colour), `muted` or `primary` |
| `visible` | boolean | `true` | yes | Shows or hides it, and starts or stops the turning |

It also takes the [props every component takes](index.md#using-a-component).

`handle.stroke` is the ring, if you want to change its colour from your own
rules.

## Examples

A spinner beside a line of text:

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space2",
    align = "center",
    children = {
        Lucy.Spinner.new({ size = "sm", variant = "muted" }),
        Lucy.Text.new({ text = "Finding a dance floor", variant = "muted", autoWidth = true }),
    },
    Parent = footer,
})
```

Shown only while a request is out:

```luau
local saving = Lucy.ref(false)

Lucy.Spinner.new({ visible = saving, Parent = wardrobe })

task.spawn(function()
    saving(true)
    saveOutfit() -- yields until the server answers
    saving(false)
end)
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Spinner")`.
