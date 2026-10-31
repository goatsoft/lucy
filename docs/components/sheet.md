---
title: Sheet
description: A panel from the side of the screen, a drawer from the bottom on touch.
---

# Sheet

A panel that slides in from the side of the screen, for an inventory, a shop,
a friends list or quick settings. A full settings or pause menu is better as a
[modal scene](../guide/scenes.md#open-a-menu-on-top). On touch it comes up from the bottom instead, where a thumb can
reach it. It has a title, a description, any content and a row of action
buttons, like a [Dialog](dialog.md). Content longer than the screen scrolls
inside it, so leave out a table's `maxHeight` inside a sheet, unless the table
should scroll on its own with its header fixed. While a sheet is open it counts
for `app:modalOpen()`; see [Hotkeys and modal input](../guide/actions.md#while-a-menu-is-open).

```luau
local settings = Lucy.Sheet.new({
    id = "settings",
    title = "Settings",
    description = "Saved to your profile.",
    children = {
        Lucy.Switch.new({ id = "music", label = "Music", checked = true }),
        Lucy.Switch.new({ id = "hints", label = "Show hints" }),
    },
    actions = {
        { text = "Done" },
    },
})

settings:open()
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `open` | boolean | `false` | yes | Whether the sheet shows |
| `title` | string | `""` | yes | The heading |
| `description` | string | `""` | yes | Text under the heading |
| `actions` | table | | | Buttons along the bottom, the same as [Dialog actions](dialog.md#actions) |
| `children` | table | | | Instances or handles to put in the scrolling body |
| `side` | string | `"right"` | | `left` or `right`: the edge the panel comes from |
| `width` | number | `360` | | The panel's width in pixels, at most 90% of the screen |
| `presentation` | string | `"auto"` | | `auto`, `panel` or `drawer` |
| `dismissible` | boolean | `true` | | Whether B, Backspace, a press outside and the close button can close it |
| `closeOnOverlay` | boolean | `true` | | Whether clicking outside closes it (off by default when `modal` is `false`) |
| `modal` | boolean | `true` | | `false` lets clicks reach what is behind it and lets focus move out of it |
| `scrim` | boolean | `true` | | `false` drops the dimmed backdrop |
| `showClose` | boolean | `true` | | Shows the close button in the corner |
| `onOpenChange` | function | | | Called with `(open, handle)` when it opens or closes |

It also takes the [props every component takes](index.md#using-a-component).
Without a `Parent`, it goes into the app's modal layer, above every scene, and
shows above anything opened before it.

With `presentation = "auto"`, the shape is picked each time the sheet opens: a
drawer from the bottom when the player last used touch, a panel from the side
otherwise. It keeps that shape until it closes, even if the player switches
input while it is open.

While a modal sheet is open, keyboard and gamepad focus stay inside it, and the
first thing in the body is selected. When it closes, focus goes back to
whatever had it before.

## Methods

| Name | What it does |
|---|---|
| `sheet:open()` | Opens it |
| `sheet:close()` | Closes it |
| `sheet:toggle()` | Opens it if closed, closes it if open |
| `sheet.presentation()` | `"panel"` or `"drawer"`, for this opening |
| `sheet.body` | The [ScrollArea](scroll-area.md) that holds `children` |
| `sheet.content` | The panel or drawer itself |

## Examples

Open a sheet from anywhere by its id:

```luau
app.state:set("ui.settings.open", true)
```

A friends list on the left that leaves the game playable behind it:

```luau
Lucy.Sheet.new({
    title = "Friends",
    side = "left",
    modal = false,
    scrim = false,
    children = friendRows,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Sheet")`.
