---
title: Scroll Area
description: A region that scrolls when its content does not fit.
---

# Scroll Area

A region that scrolls when its content does not fit: a song list, a shop, the
rules in a dialog. It works with the mouse wheel, touch and gamepad, and keeps
the focused item in view when the player moves with Tab or the arrow keys.

```luau
Lucy.ScrollArea.new({
    size = UDim2.new(1, 0, 0, 300),
    padding = "Space2",
    children = {
        Lucy.Stack.new({ gap = "Space1", children = songRows }),
    },
    Parent = panel,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `direction` | string | `"vertical"` | | `vertical`, `horizontal` or `both` |
| `size` | UDim2 | fills the parent | | The area's size |
| `maxHeight` | number, ref or getter | none | | Fits the content up to this height, then scrolls |
| `padding` | spacing | none | | Space around the inside edge of the content |
| `scrollbar` | string | `"hover"` | | When the scroll bar shows, see [Scroll bar](#scroll-bar) |
| `hideDelay` | number | `0.6` | | Seconds the bar stays after scrolling stops |
| `fade` | boolean | `true` | | Fade the edges there is more to scroll past, see [Edge fades](#edge-fades) |
| `children` | table | | | Instances, handles or functions to put in it |
| `visible` | boolean | `true` | yes | Shows or hides the area |

It also takes the [props every component takes](index.md#using-a-component).

A spacing value is a token name (`"Space0"` to `"Space6"`, `"Space8"`), a
number of pixels or a UDim.

`handle.Instance` is the ScrollingFrame and `handle.content` is the frame inside
it that holds the children. The area lays out nothing itself: put a
[Stack](stack.md) inside to arrange a list.

With `maxHeight`, the area takes its width from `size` (or fills the parent) and
its height from the content, up to `maxHeight` pixels. Short content fits with
no scroll bar; long content stops at the cap and scrolls.

## Scroll bar

`scrollbar` decides when the bar shows, for the direction the area scrolls in:

| Value | The bar shows |
|---|---|
| `hover` | While the player scrolls, or while the mouse is over the area |
| `auto` | Whenever the content does not fit |
| `always` | All the time, even when the content fits |
| `scroll` | While the player scrolls: wheel, drag, touch or right stick |
| `glimpse` | For a moment when the mouse comes over the area, and while scrolling |

Touch and gamepad have no hover, so on those `hover` acts like `scroll`. Apart
from `always`, the bar only shows when there is something to scroll to. It
fades in and out without changing the space it takes, so the content never
moves when it shows.

## Edge fades

While there is more to scroll past an edge, that edge fades into the surface
behind the area: the page background, a Panel's card or a Select's list. A
control the edge cuts through then reads as going on, not as broken. The fades
come and go as the player scrolls, and never take clicks. Turn them off with
`fade = false`, for an area over a picture, say, where a solid fade would show.

## Gamepad and keyboard

Gamepad selection moves through the buttons and other controls inside the
area, and the area scrolls to show each one. Tab and the arrow keys do the
same.

When the area holds nothing to select, such as a long block of rules text, and
the content does not fit, the area itself can be selected instead, so the
player can still scroll it with a gamepad.

## Examples

A dialog body that grows with its text and scrolls past 320 pixels:

```luau
Lucy.ScrollArea.new({
    maxHeight = 320,
    children = {
        Lucy.Text.new({ text = rules, variant = "p" }),
    },
    Parent = body,
})
```

A row of cards that scrolls sideways:

```luau
Lucy.ScrollArea.new({
    direction = "horizontal",
    size = UDim2.new(1, 0, 0, 220),
    children = {
        Lucy.Stack.new({ direction = "horizontal", gap = "Space3", children = cards }),
    },
    Parent = shop,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("ScrollArea")`.
