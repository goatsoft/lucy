<!-- Made by scripts/skills.ts from docs/components/badge.md. Edit the doc, not this file. -->
# Badge

A small label for a status or a count, such as "New" on a shop item.

```lua
Lucy.Badge.new({ text = "New", Parent = card })
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `text` | string | `"Badge"` | yes | The label |
| `variant` | string | `"default"` | yes | `default`, `secondary`, `destructive` or `outline` |
| `visible` | boolean | `true` | yes | Shows or hides the badge |

It also takes the [props every component takes](index.md#using-a-component).

## Examples

A badge for each variant:

```lua
for _, variant in { "default", "secondary", "destructive", "outline" } do
    Lucy.Badge.new({ text = variant, variant = variant, Parent = row })
end
```

A count that follows a value:

```lua
local unread = Lucy.ref(3)

Lucy.Badge.new({
    text = function() return tostring(unread()) end,
    variant = "destructive",
    visible = function() return unread() > 0 end,
    Parent = header,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Badge")`.
