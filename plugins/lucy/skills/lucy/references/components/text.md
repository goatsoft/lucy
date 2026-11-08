<!-- Made by scripts/skills.ts from docs/components/text.md. Edit the doc, not this file. -->
# Text

Text in the theme's fonts and colours: headings, body copy, muted notes and
labels. It wraps to fill its parent's width unless you ask it to fit the text.
`handle.Instance` is the TextLabel.

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
| `reveal` | number or `true` | | | Types the text out, this many characters a second (`true`: 40), and again from the start whenever the text changes |
| `revealing` | boolean | `false` | yes, read only | Whether it is typing out now |
| `value` | number | | yes | Shows this number instead of `text`, formatted by `format` |
| `format` | function | `Lucy.Format.number` | | Turns `value` into text, such as ``function(n) return `+{n} XP` end`` |
| `count` | number or `true` | | | Counts up to `value` over this many seconds (`true`: 0.8), and on from where it is when it changes |
| `from` | number | `0` | | Where the first count starts |
| `counting` | boolean | `false` | yes, read only | Whether it is counting now |

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

```luau
local coins = app.state:ref("player.coins")

Lucy.Text.new({
    text = function() return `Coins: {coins()}` end,
    variant = "h3",
    Parent = hud,
})
```

Text that fits itself, for use in a row:

```luau
Lucy.Text.new({ text = "Level 12", variant = "small", autoWidth = true, Parent = row })
```

Rich text:

```luau
Lucy.Text.new({ text = "Press <b>E</b> to dance", richText = true, Parent = prompt })
```

Text that types itself out, as a character's line in a dialogue box. The whole line is laid out
from the start, so words never jump to the next line as they appear. `text:skipReveal()` shows the
rest at once (a press to skip ahead), and `text.Revealed` fires once it is all out:

```luau
local line = Lucy.Text.new({
    text = function() return speech() end,
    variant = "lead",
    reveal = 34,
    Parent = dialogue,
})
line.Revealed:Connect(function()
    nextButton:set("visible", true)
end)
```

A number that counts up to its value, such as XP on a results screen. It counts on from where it
is whenever the value changes, so a second reward adds to the first. `text:skipCount()` lands it at
once, and `text.Counted` fires when it lands:

```luau
local xp = app.state:ref("player.xp")

Lucy.Text.new({
    value = xp,
    count = true,
    format = function(n)
        return `{Lucy.Format.number(n)} XP`
    end,
    variant = "h2",
    Parent = results,
})
```

Both are [composables](../reference/composables.md) underneath, `useReveal` and `useCount`, so
anything else can type out or count up the same way.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Text")`, and `Lucy.Preview.show("TextMotion")`
for the reveal and the count.
