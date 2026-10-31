<!-- Made by scripts/skills.ts from docs/components/avatar.md. Edit the doc, not this file. -->
# Avatar

A player's headshot in a circle. Bots and empty slots, which have no Roblox
account, show the first letters of their name instead.

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space2",
    children = {
        Lucy.Avatar.new({ name = "DJ Lucy", size = "lg" }), -- no userId: shows DL
        Lucy.Avatar.new({ name = "Nova", size = "lg" }),
        Lucy.Avatar.new({ name = "Beatrix", size = "lg" }),
        Lucy.Avatar.new({ name = "Kai", size = "lg" }),
        Lucy.Avatar.new({ name = "Juno", size = "lg" }),
    },
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `userId` | number | `0` | yes | The player's user id. `0` or below shows the monogram |
| `name` | string | `""` | yes | The name the monogram's letters come from |
| `size` | string | `"md"` | yes | `sm` (32 pixels), `md` (40) or `lg` (56) |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `square` | boolean | `false` | | Rounded corners instead of a circle |

It also takes the [props every component takes](index.md#using-a-component).

The monogram is the first letter of each of the first two words in `name`:
`"DJ God"` shows `DG`, `"Moonwalker"` shows `M`, and no name shows `?`.

Its parts are on the handle: `avatar.image` is the headshot and
`avatar.monogram` the letters. `Lucy.Avatar.headshot(userId)` gives the
headshot url on its own, and `Lucy.Avatar.initials(name)` the letters.

## Examples

A Top Dancers slot that changes as players and bots come and go:

```luau
local slot = app.state:ref("topDancers.1") -- { userId = number, name = string }

Lucy.Avatar.new({
    userId = function() return slot().userId end,
    name = function() return slot().name end,
    size = "lg",
    Parent = podium,
})
```

In a row of the Crew list:

```luau
Lucy.Item.new({
    title = friend.DisplayName,
    description = `@{friend.Name}`,
    media = Lucy.Avatar.new({ userId = friend.UserId, name = friend.DisplayName }),
    Parent = crewList,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Avatar")`.
