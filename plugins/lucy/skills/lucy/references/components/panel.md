<!-- Made by scripts/skills.ts from docs/components/panel.md. Edit the doc, not this file. -->
# Panel

A card with a title and description at the top, your content in the middle and
an optional row of buttons at the bottom. Use it for menus, shop items and
settings groups.

```luau
Lucy.Panel.new({
    title = "Moonwalk",
    description = "Glide backwards across the Dance Floor",
    size = UDim2.fromOffset(360, 0),
    children = { Lucy.Text.new({ text = "300 coins", variant = "large" }) },
    footer = {
        Lucy.Button.new({
            text = "Buy",
            icon = "lucide-extended:shopping-bag-filled",
            onClick = function() app.toast("Moonwalk unlocked") end,
        }),
        Lucy.Button.new({ text = "Try it on", variant = "outline" }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `title` | string | `""` | yes | The heading |
| `description` | string | `""` | yes | Text under the heading |
| `visible` | boolean | `true` | yes | Shows or hides the panel |
| `children` | table | | | Instances or handles to put in the content area |
| `footer` | table | | | Instances or handles to put in the footer, such as buttons |
| `size` | UDim2 | fills the width, height fits the content | | The panel's size |
| `maxWidth` | number | | | The widest it gets, in pixels |
| `minWidth` | number | | | The narrowest it gets, in pixels |
| `aspectRatio` | number | | | Keeps a fixed shape, such as `16 / 9` |

It also takes the [props every component takes](index.md#using-a-component).

## Parts

| Name | What it is |
|---|---|
| `panel.header` | The frame with the title and description |
| `panel.content` | The frame that holds `children`; add more to it any time |
| `panel.footer` | The frame that holds `footer` (hidden when there is none) |

## Examples

A fixed width panel with a form:

```luau
local panel = Lucy.Panel.new({
    title = "Settings",
    size = UDim2.fromOffset(360, 0),
    children = {
        Lucy.Switch.new({ label = "Music", checked = true }),
        Lucy.Switch.new({ label = "Club lights", checked = true }),
    },
    footer = { Lucy.Button.new({ text = "Done", onClick = closeSettings }) },
    Parent = frame,
})
```

Add content later:

```luau
Lucy.Text.new({ text = "Crowd volume saved", variant = "muted", Parent = panel.content })
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Panel")`.
