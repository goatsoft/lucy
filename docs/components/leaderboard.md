---
title: Leaderboard
description: Players ranked as a podium, with your own place pinned at the bottom.
---

# Leaderboard

Players ranked best first, laid out as a podium. 1st is big, 2nd and 3rd sit
under it a little smaller, and everyone after them is a line of text. Your
own row is lit; when you are not on the board, it is pinned at the bottom.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-leaderboard-light.webp" alt="Leaderboard example" loading="lazy"><img class="example-dark" src="/images/examples/components-leaderboard-dark.webp" alt="Leaderboard example" loading="lazy"></figure>

```luau
Lucy.Leaderboard.new({
    rows = {
        { name = "Nova", value = 9840 },
        { name = "Kai", value = 9125 },
        { name = "Juno", value = 8410 },
        { name = "Beatrix", value = 7360 },
        { name = "Remy", value = 6220 },
    },
    own = { name = app.state:get("player.name"), value = 1250, rank = 37 },
    medals = { "lucide-extended:crown-filled", "lucide-extended:crown-filled", "lucide-extended:crown-filled" },
    format = function(hype) return `{Lucy.Leaderboard.formatNumber(hype)} hype` end,
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `rows` | array, ref or getter | `{}` | | The players, best first: `{ userId, name, value, rank }`. `rank` is the row's place when left out |
| `own` | table, ref or getter | | | The player's own entry. Lit when it is on the board, pinned at the bottom when it is not |
| `unranked` | string, ref or getter | `"-"` | | The pinned row's rank when `own.rank` is `nil`, such as `"100+"` |
| `format` | function | `14,850` | | Turns a value into text |
| `medals` | table, `false`, ref or getter | | | Icons for 1st, 2nd and 3rd, before the number. `false` takes away the gold, silver and bronze too |
| `podium` | boolean | `true` | | `false` makes every row the same size |
| `avatars` | `"top"` or boolean | `"top"` | | Headshots on the podium and your row. `true` on every row, `false` on none |
| `avatarShape` | string | `"circle"` | | `circle`, or `square` for rounded corners |
| `loading` | boolean, ref or getter | `false` | | Pulsing rows while the scores load |
| `placeholders` | number | `5` | | How many pulsing rows |
| `empty` | string | | | Shown when nobody is on the board |
| `height` | number, ref or getter | | | The rows scroll in this many pixels, and your row stays under them. The board keeps its size while it loads and fills |
| `size` | string | `"md"` | yes | `sm`, `md` or `lg`, for the whole board |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

A player with no `userId` gets a monogram, like a bot in [Avatar](avatar.md).
Rows are matched by `userId`, or `name` when there is none, so new scores move
rows instead of rebuilding them.

1st, 2nd and 3rd are coloured with `$MedalGold`, `$MedalSilver` and
`$MedalBronze`. Set them in your theme to match your game.
`Lucy.Leaderboard.formatNumber(14850)` gives `"14,850"`.

The handle has `board.list`, `board.pinned`, `board.scroller` (with `height`),
`board.skeletons`, `board.emptyLabel`, and for each row `board.rowFor(id)`,
`board.tierOf(id)`, `board.rankLabelFor(id)`, `board.medalFor(id)`,
`board.avatarFor(id)`, `board.nameLabelFor(id)` and `board.valueLabelFor(id)`.

## Examples

The hype board in a dialog. With `height`, the dialog keeps its size whether
two dancers are on the board or twenty, and while the scores load (`loading`):

<!-- preview solo -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-leaderboard-2-light.webp" alt="Leaderboard example" loading="lazy"><img class="example-dark" src="/images/examples/components-leaderboard-2-dark.webp" alt="Leaderboard example" loading="lazy"></figure>

```luau
Lucy.Dialog.new({
    id = "hype-board",
    title = "Hype",
    size = "lg",
    children = {
        Lucy.Leaderboard.new({
            rows = {
                { name = "Nova", value = 9840 },
                { name = "Kai", value = 9125 },
                { name = "Juno", value = 8410 },
                { name = "Beatrix", value = 7360 },
            },
            own = { name = app.state:get("player.name"), value = 1250, rank = 37 },
            format = function(hype) return `{Lucy.Leaderboard.formatNumber(hype)} hype` end,
            height = 300,
        }),
    },
}):open()
```

The rows usually come from the server. Show pulsing rows until they do:

```luau
local scores = Lucy.ref(nil)
task.spawn(function()
    scores(app.server:call("hype.top"))
end)

Lucy.Leaderboard.new({
    rows = function() return scores() and scores().rows or {} end,
    own = function() return scores() and scores().me end,
    loading = function() return scores() == nil end,
    unranked = "100+",
    height = 300,
    Parent = hypeDialog,
})
```

Square headshots, for a board that sits in a grid of square tiles:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-leaderboard-3-light.webp" alt="Leaderboard example" loading="lazy"><img class="example-dark" src="/images/examples/components-leaderboard-3-dark.webp" alt="Leaderboard example" loading="lazy"></figure>

```luau
Lucy.Leaderboard.new({
    rows = {
        { name = "Nova", value = 42 },
        { name = "Kai", value = 37 },
        { name = "Juno", value = 31 },
        { name = "Remy", value = 18 },
    },
    avatarShape = "square",
    format = function(wins) return `{wins} wins` end,
    Parent = parent,
})
```

Nobody on the board yet:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-leaderboard-4-light.webp" alt="Leaderboard example" loading="lazy"><img class="example-dark" src="/images/examples/components-leaderboard-4-dark.webp" alt="Leaderboard example" loading="lazy"></figure>

```luau
Lucy.Leaderboard.new({
    rows = {},
    empty = "No hype yet. Get on the Dance Floor.",
    Parent = parent,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Leaderboard")`.
