---
title: Text
description: Headings, body copy and labels.
---

# Text

Text in the theme's fonts and colours: headings, body copy, muted notes and
labels. It wraps to fill its parent's width unless you ask it to fit the text.
`handle.Instance` is the TextLabel.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-text-light.webp" alt="Text example" loading="lazy"><img class="example-dark" src="/images/examples/components-text-dark.webp" alt="Text example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
    gap = "Space1",
    children = {
        Lucy.Text.new({ text = "Club Lucy", variant = "h1", align = "center" }),
        Lucy.Text.new({ text = "DJ Lucy is on the decks tonight", variant = "lead", align = "center" }),
        Lucy.Text.new({ text = "Now playing: Neon Nights, 124 BPM", variant = "muted", align = "center" }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `text` | string | `""` | yes | The text |
| `variant` | string | `"p"` | yes | The style, see below |
| `align` | string | `"left"` | yes | `left`, `center` or `right` |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `autoWidth` | boolean | `false` | | Sizes to the text instead of filling the width, and stops wrapping |
| `richText` | boolean | `false` | | Turns on Roblox rich text tags such as `<b>` |

It also takes the [props every component takes](index.md#using-a-component).

| Variant | Use it for |
|---|---|
| `h1` to `h4` | Headings, largest first |
| `p` | Body text |
| `lead` | A larger, softer opening line |
| `large` | Text that should stand out |
| `small` | Small print |
| `muted` | Notes and hints, in a softer colour |
| `label` | Labels for fields and settings |

## Examples

A label that follows game state:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-text-2-light.webp" alt="Text example" loading="lazy"><img class="example-dark" src="/images/examples/components-text-2-dark.webp" alt="Text example" loading="lazy"></figure>

```luau
local coins = app.state:ref("player.coins")

Lucy.Text.new({
    text = function() return `Coins: {coins()}` end,
    variant = "h3",
    Parent = hud,
})
```

Text that fits itself, for use in a row:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-text-3-light.webp" alt="Text example" loading="lazy"><img class="example-dark" src="/images/examples/components-text-3-dark.webp" alt="Text example" loading="lazy"></figure>

```luau
Lucy.Text.new({ text = "Level 12", variant = "small", autoWidth = true, Parent = row })
```

Rich text:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-text-4-light.webp" alt="Text example" loading="lazy"><img class="example-dark" src="/images/examples/components-text-4-dark.webp" alt="Text example" loading="lazy"></figure>

```luau
Lucy.Text.new({ text = "Press <b>E</b> to dance", richText = true, Parent = prompt })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Text")`.
