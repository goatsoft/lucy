---
title: Leaderboard
description: Ranked players with medals for the top three and the player's own row pinned.
---

# Leaderboard

Players ranked best first, each with their place, headshot, name and score. The
top three wear gold, silver and bronze, and can show the game's medal icons in
place of their number. The player's own row is lit; when they are not in the
list, their row is pinned under it with their rank. While the scores load,
pulsing rows stand in for the list.

```luau
Lucy.Leaderboard.new({
    rows = topScores, -- { { userId, name, value } }, best first
    own = { userId = player.UserId, name = player.DisplayName, value = 320, rank = 37 },
    format = function(value)
        return `{Lucy.Leaderboard.formatNumber(value)} PTS`
    end,
    medals = { "lucide-extended:chess-queen-duotone", "lucide-extended:crown-duotone", "lucide-extended:crown-duotone" },
    empty = "No one has danced yet. Be the first.",
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `rows` | table, ref or getter | `{}` | | The entries, best first: `{ userId, name, value, rank? }`. `rank` defaults to the row's place |
| `own` | table, ref or getter | `nil` | | The player's entry. Their row is lit when listed, else pinned under the list |
| `unranked` | string | `"-"` | | The pinned rank when `own.rank` is not known (`"100+"`, say) |
| `format` | function | commas | | Turns a value into its text. Text values are shown as they are |
| `medals` | table or `false` | `nil` | | Icons for 1st, 2nd and 3rd in place of the number. `false` leaves out the medal colours too |
| `loading` | boolean, ref or getter | `false` | | Pulsing rows in place of the list |
| `placeholders` | number | `5` | | How many pulsing rows |
| `empty` | string | `nil` | | Shown when there are no rows |
| `avatars` | boolean | `true` | | The headshots (an entry with no `userId` shows a monogram) |
| `size` | string | `"md"` | yes | `sm`, `md` or `lg` (a board in the world, say) |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

Rows are keyed by `userId` (or `name`), so new scores update rows in place and
move them rather than building them again.

The colours come from the theme: `$MedalGold`, `$MedalSilver` and
`$MedalBronze` for the top three, `$Accent` and `$Ring` for the player's row.
Set the medal tokens in your theme to match your game.

Its parts are on the handle: `board.list`, `board.pinned`, `board.skeletons`,
`board.emptyLabel`, and per row `board.rowFor(id)`, `board.rankLabelFor(id)`,
`board.medalFor(id)`, `board.nameLabelFor(id)` and `board.valueLabelFor(id)`.
`Lucy.Leaderboard.formatNumber(14850)` gives `"14,850"`.

## Examples

A board that loads from the server, ALL TIME or THIS WEEK:

```luau
local period = Lucy.ref("all")
local answer = Lucy.ref(nil)

Lucy.watch(period, function(p)
    answer(nil)
    task.spawn(function()
        answer(app.server:call("leaderboards.get", "score", p))
    end)
end, { immediate = true })

Lucy.Leaderboard.new({
    rows = function() return answer() and answer().rows or {} end,
    own = function() return answer() and answer().me end,
    loading = function() return answer() == nil end,
    unranked = "100+",
    Parent = dialogBody,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Leaderboard")`.
