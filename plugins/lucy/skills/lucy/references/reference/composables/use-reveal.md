<!-- Made by scripts/skills.ts from docs/reference/composables/use-reveal.md. Edit the doc, not this file. -->
# useReveal

`Lucy.useReveal` reveals a string a character at a time and returns a `visible`
count you can bind straight to a TextLabel's `MaxVisibleGraphemes`.

Because `MaxVisibleGraphemes` hides later letters without changing the string,
Roblox lays out the full text on frame one so words do not jump onto new lines
as they appear.

## Usage

```luau
local typed = Lucy.useReveal(text, options?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `text` | `MaybeRef<string>` | required | Text to reveal |
| `options` | `table?` | `{}` | Rate and rich text options |

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `rate` | `number` | `40` | Characters shown per second |
| `rich` | `boolean` | `false` | Skips rich text tags (`<b>`, `<font>`) instead of counting them |

### Returns

| Name | Type | What it is |
|---|---|---|
| `visible()` | `() -> number` | Number of characters to show (`-1` once finished) |
| `revealing()` | `() -> boolean` | `true` while typing |
| `skip()` | `() -> ()` | Shows the rest of the text at once |
| `done` | `Lucy.Signal` | Fires when the text finishes revealing |

## Example: DJ dialogue

Type out DJ Lucy's spoken line with a button to skip or move on:

```luau
local speech = app.state:ref("npc.dialogue")
local typed = Lucy.useReveal(speech, { rate = 32, rich = true })

local label = Lucy.new "TextLabel" {
    Text = speech,
    RichText = true,
    MaxVisibleGraphemes = typed.visible,
    Parent = dialogueBox,
}

local skipOrNextButton = Lucy.Button.new({
    text = function()
        return if typed.revealing() then "Skip" else "Next"
    end,
    onClick = function()
        if typed.revealing() then
            typed.skip()
        else
            advanceDialogue()
        end
    end,
    Parent = dialogueBox,
})
```

[Text](../../components/text.md) has this built in via `reveal`:
`Lucy.Text.new({ text = line, reveal = 32 })`.
