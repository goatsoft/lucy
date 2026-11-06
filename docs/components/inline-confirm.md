---
title: Inline Confirm
description: Asks "Are you sure?" in place, with YES and NO.
---

# Inline Confirm

Asks the player to confirm without covering the screen. Its content steps aside
for "Are you sure?" with YES and NO; NO puts the content back. Use it where a
[Dialog](dialog.md) would hide the very thing being asked about: skipping a
[Tour](tour.md) (it asks this way), clearing a routine, leaving a queue.

```luau
local confirm
confirm = Lucy.InlineConfirm.new({
    children = {
        Lucy.Text.new({ text = "Your routine has 12 moves." }),
        Lucy.Button.new({ text = "CLEAR", variant = "outline", onClick = function()
            confirm:ask()
        end }),
    },
    yesVariant = "destructive",
    onYes = function() clearRoutine() end,
    Parent = panel,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `question` | string | `"Are you sure?"` | yes | What it asks |
| `yes` | string | `"YES"` | yes | The YES button's text |
| `no` | string | `"NO"` | yes | The NO button's text |
| `yesVariant` | string | `"default"` | yes | The YES [Button](button.md)'s variant (`destructive` for a loss) |
| `noVariant` | string | `"outline"` | yes | The NO button's variant. Make NO the solid one (`default`) to steer players to it |
| `asking` | boolean | `false` | yes | Whether it is asking now |
| `visible` | boolean | `true` | yes | Shows or hides it |
| `children` | table | | | The content shown while it is not asking |
| `onYes` | function | | | `(confirm)`: the player said YES |
| `onNo` | function | | | `(confirm)`: the player said NO, or pressed back |

It also takes the [props every component takes](index.md#using-a-component).

## Methods

| Method | What it does |
|---|---|
| `confirm:ask()` | Swaps the content for the question |
| `confirm:answer(yes)` | Answers as the player would |
| `confirm:cancel()` | Puts the content back without an answer |
| `confirm.asking()` | Whether it is asking (tracked) |

## Input

While it asks, back (B, Backspace) answers NO. With a gamepad or keyboard,
asking moves focus to NO, the safe answer, and NO gives focus back to what had
it (usually the button that asked).

## Look

The question is semibold in `Foreground` (inside a Tour callout,
`PopoverForeground`), with small YES and NO buttons beside it (YES
`default`, NO `outline` unless you swap them). It fills the width of its parent and grows to fit. Parts:
`confirm.content`, `confirm.prompt`, `confirm.question`, `confirm.yes` and
`confirm.no`. Tags: `ui-inline-confirm`, `ui-inline-confirm-asking`,
`ui-inline-confirm-question`.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("InlineConfirm")`.
