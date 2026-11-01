---
title: Marquee
description: One line of text that scrolls back and forth, or round like a ticker, when it is too long to fit.
---

# Marquee

A single line that slides to show all of itself when it is wider than its
space, then slides back, holding a moment at each end. Use it for song titles,
tickers and names on boards, where wrapping would break the layout. With
`loop` on it goes round instead, like a ticker: a copy of the text follows the
first one a gap behind, so it never stops or jumps back.

```luau
local track = app.state:ref("server.dj.title")

Lucy.Marquee.new({
    text = function()
        return track() or ""
    end,
    variant = "large",
    Parent = nowPlaying,
})
```

Text that fits stays still and left aligned. It only moves while visible, and
starts again from the beginning whenever its text changes, except with `loop`:
a ticker carries on from where it was, so live text such as a score or a
countdown never makes it stop. When the player asks
for reduced motion it stays still, cut off at the edge.

The Marquee fills its parent's width and is as tall as one line of its variant,
so give it a parent with a width, such as a [Stack](stack.md) column.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `text` | string | `""` | yes | The line |
| `variant` | string | `"p"` | yes | Its style: any [Text](text.md) variant |
| `visible` | boolean | `true` | yes | Shows or hides it, and starts or stops the moving |
| `speed` | number | `40` | | Pixels a second while it moves |
| `pause` | number | `1.5` | | Seconds it holds at each end; with `loop`, only before it first moves |
| `loop` | boolean | `false` | | Goes round in one direction, its copy following, instead of back and forth |
| `gap` | number | `48` | | Pixels between the text and its copy when it loops |
| `richText` | boolean | `false` | | Turns on Roblox rich text tags such as `<b>` |

It also takes the [props every component takes](index.md#using-a-component).

`handle.strip` is the moving TextLabel, for your own rules: tag it and style it
with tokens. `handle.scrolling` says whether it is moving right now. With `loop`,
`handle.repeatStrip` is the copy; it takes its text size, color and font from
the strip, so style the strip.

## Examples

A smaller second line beside the title, with rich text:

```luau
Lucy.Marquee.new({
    text = `{title}  <font size="14" transparency="0.25">{artist}</font>`,
    variant = "h3",
    richText = true,
    Parent = panel,
})
```

A slower ticker that waits longer at each end:

```luau
Lucy.Marquee.new({
    text = "Sign up at The Lab to dance in the next round",
    variant = "muted",
    speed = 25,
    pause = 3,
    Parent = footer,
})
```

A ticker that goes round without stopping, for a long line of news:

```luau
Lucy.Marquee.new({
    text = "Sign-ups are open at The Lab · DJ GOD is on the decks · Next round in 2 minutes",
    variant = "large",
    loop = true,
    speed = 90,
    Parent = ticker,
})
```
