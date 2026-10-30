<!-- Made by scripts/skills.ts from docs/components/item.md. Edit the doc, not this file. -->
# Item

A row in a list: a picture or icon on the left, a title and a description in
the middle, and buttons or a switch on the right. Use it for song lists,
inventories, settings and friend lists.

```lua
Lucy.Item.new({
    title = "Moonwalk",
    description = "Unlocked at level 5",
    media = icon,
    actions = { Lucy.Button.new({ text = "Equip", size = "sm" }) },
    variant = "outline",
    Parent = list,
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

A song list where one song is picked at a time:

```lua
local picked = Lucy.ref(songs[1].id)

local rows = {}
for _, song in songs do
    table.insert(rows, Lucy.Item.new({
        title = song.name,
        description = `{song.genre}, {song.bpm} BPM`,
        media = cover(song),
        variant = "outline",
        selected = function() return picked() == song.id end,
        onClick = function() picked(song.id) end,
    }))
end

Lucy.Stack.new({ gap = "Space2", children = rows, Parent = list })
```

A setting with a switch:

```lua
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
