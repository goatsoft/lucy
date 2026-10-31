<!-- Made by scripts/skills.ts from docs/components/alert.md. Edit the doc, not this file. -->
# Alert

A box with a title and a line or two of text that stays on screen: a server
notice, a failed purchase, a rule the player should know. For a message that
comes and goes on its own, use a [toast](toaster.md) instead.

```luau
Lucy.Alert.new({
    title = "Server restarting in 5 minutes",
    description = "Your progress is saved. You will join a new server.",
    variant = "warning",
    Parent = frame,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `title` | string | `""` | yes | The first line. Hidden when empty |
| `description` | string | `""` | yes | The text under it, in a muted colour. Hidden when empty |
| `variant` | string | `"default"` | yes | `default`, `destructive`, `success`, `warning` or `info` |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `icon` | Instance or handle | | | Shown before the text |
| `children` | table | | | More content under the description, such as a button |

It also takes the [props every component takes](index.md#using-a-component).

It fills the width of its parent and grows to fit its text. Its parts are on
the handle: `alert.icon`, `alert.content`, `alert.title` and `alert.description`.

## Looks

A card coloured box with a border. Every variant except `default` fills the box
with a pale wash of the theme's matching colour (`DestructiveSubtle`,
`SuccessSubtle`, `WarningSubtle` or `InfoSubtle`), rings it in the full colour,
and sets the title, description and icon in a deep shade of it
(`DestructiveSubtleForeground` and the rest), worked out to WCAG AA contrast.
See [Accessibility](../guide/accessibility.md).

## Examples

A failed purchase with a way to try again:

```luau
Lucy.Alert.new({
    variant = "destructive",
    title = "Purchase failed",
    description = "You were not charged. Try again in a moment.",
    children = {
        Lucy.Button.new({ text = "Try again", size = "sm", variant = "outline", onClick = retry }),
    },
    Parent = shop,
})
```

A notice that follows game state:

```luau
local restartIn = Lucy.ref(0)

Lucy.Alert.new({
    variant = "warning",
    title = function() return `Server restarting in {restartIn()} minutes` end,
    visible = function() return restartIn() > 0 end,
    Parent = hud,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Alert")`.
