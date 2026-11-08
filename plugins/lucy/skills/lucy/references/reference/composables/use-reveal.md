<!-- Made by scripts/skills.ts from docs/reference/composables/use-reveal.md. Edit the doc, not this file. -->
# useReveal

`Lucy.useReveal` types a string out at a set rate, returning a `visible` count
designed to be bound directly to a TextLabel's `MaxVisibleGraphemes`.

Because `MaxVisibleGraphemes` clips text without altering the underlying layout,
the full text is measured and laid out by the Roblox engine from the very first
frame. Words never jump between lines or wrap unpredictably as they appear.

## Usage

```luau
local typed = Lucy.useReveal(text, options?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `text` | `MaybeRef<string>` | required | The text string to reveal |
| `options` | `table?` | `{}` | Reveal options (see below) |

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `rate` | `number` | `40` | Characters revealed per second |
| `rich` | `boolean` | `false` | Skips rich text markup tags (`<b>`, `<font>`) without delaying playback |

### Returns

| Name | Type | What it is |
|---|---|---|
| `visible()` | `() -> number` | Grapheme count to display (`-1` once fully revealed) |
| `revealing()` | `() -> boolean` | `true` while typing is actively progressing |
| `skip()` | `() -> ()` | Immediately reveals the entire remaining text |
| `done` | `Lucy.Signal` | Fires whenever the full text finishes revealing |

## Example: DJ Lucy dialogue in Club Lucy

Type out DJ Lucy's spoken lines, with a button to skip typing or advance:

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

The [Text](../../components/text.md) component provides this built in via the
`reveal` prop: `Lucy.Text.new({ text = line, reveal = 32 })`.
