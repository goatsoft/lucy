<!-- Made by scripts/skills.ts from docs/components/item.md. Edit the doc, not this file. -->
# Item

A row in a list: a picture or icon on the left, a title and a description in
the middle, and buttons or a switch on the right. Use it for song lists,
inventories, settings and friend lists.

```luau
Lucy.Stack.new({
    gap = "Space2",
    size = UDim2.fromOffset(420, 0),
    automaticSize = Enum.AutomaticSize.Y,
    children = {
        Lucy.Item.new({
            title = "Moonwalk",
            description = "Unlocked at level 5",
            media = Lucy.Icon.new({ icon = "lucide-extended:sparkles-filled", size = "lg" }),
            actions = { Lucy.Button.new({ text = "Equip", size = "sm" }) },
            variant = "outline",
        }),
        Lucy.Item.new({
            title = "Robot",
            description = "150 coins",
            media = Lucy.Icon.new({ icon = "lucide-extended:zap-filled", size = "lg" }),
            actions = { Lucy.Button.new({ text = "Buy", size = "sm", variant = "secondary" }) },
            variant = "outline",
        }),
    },
    Parent = parent,
})
```

Give it `onClick` and the whole row can be clicked, tapped or selected with a
gamepad, like a [Pressable](pressable.md). Without it the row is plain, and
only its actions take input.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `title` | string | `""` | yes | The main line |
| `description` | string | `""` | yes | A muted line under the title. Hidden when empty |
| `variant` | string | `"default"` | yes | `default` (no background), `outline` (a border) or `muted` (a muted background) |
| `size` | string | `"md"` | yes | `md`, or `sm` for less space around the content |
| `selected` | boolean | `false` | yes | Shows it as picked |
| `disabled` | boolean | `false` | yes | Fades the text and, when clickable, ignores clicks |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `media` | Instance or handle | | | What goes before the text: an icon, a cover or an [Avatar](avatar.md) |
| `actions` | table | | | Instances or handles after the text, in a row |
| `onClick` | function | | | Makes the whole row clickable; called with the handle |

It also takes the [props every component takes](index.md#using-a-component).

The row fills the width of its parent and grows to fit its text. The text takes
whatever width is left between the media and the actions, and wraps.

## Methods and events

Only when the row has `onClick`:

| Name | What it does |
|---|---|
| `item.Activated` | A signal that fires on every click |
| `item:click()` | Runs a click from code, as if the player clicked |

Its parts are on the handle too: `item.media`, `item.content`, `item.title`,
`item.description` and `item.actions`.

## Looks

The default variant has no background. A clickable row shows the accent colour
under the pointer and the muted colour while pressed. A selected row keeps the
accent background and gets a ring around it.

## Examples

A track list where one track is picked at a time:

```luau
local picked = Lucy.ref(tracks[1].id)

local rows = {}
for _, track in tracks do
    table.insert(rows, Lucy.Item.new({
        title = track.name,
        description = `{track.artist}, {track.bpm} BPM`,
        media = cover(track),
        variant = "outline",
        selected = function() return picked() == track.id end,
        onClick = function() picked(track.id) end,
    }))
end

Lucy.Stack.new({ gap = "Space2", children = rows, Parent = list })
```

A setting with a switch:

```luau
Lucy.Item.new({
    title = "Streamer mode",
    description = "Plays only music that is safe to stream.",
    actions = { Lucy.Switch.new({ checked = streamerMode }) },
    Parent = settings,
})
```

Put a long list in a [Scroll Area](scroll-area.md).

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Item")`.
