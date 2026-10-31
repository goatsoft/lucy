<!-- Made by scripts/skills.ts from docs/components/dialog.md. Edit the doc, not this file. -->
# Dialog

A modal window above every scene, with a title, a description, any content and
a row of action buttons. While it is open, keyboard and gamepad focus stay
inside it and the back button (B or Backspace) closes it.

```luau
local quit = Lucy.Dialog.new({
    id = "quit",
    title = "Leave the club?",
    description = "Your dance combo resets. Your coins are saved.",
    actions = {
        { text = "Keep dancing", variant = "outline" },
        { text = "Leave", variant = "destructive", onClick = function() app.toast("See you next time") end },
    },
})

quit:open()
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `open` | boolean | `false` | yes | Whether the dialog shows |
| `title` | string | `""` | yes | The heading |
| `description` | string | `""` | yes | Text under the heading |
| `actions` | table | | | Buttons along the bottom, see [Actions](#actions) |
| `children` | table | | | Instances or handles to put in the content area |
| `dismissible` | boolean | `true` | | Whether B, Backspace, the overlay and the close button can close it |
| `closeOnOverlay` | boolean | `true` | | Whether clicking outside closes it (off by default when `modal` is `false`) |
| `modal` | boolean | `true` | | `false` lets clicks reach what is behind it and lets focus move out of it |
| `scrim` | boolean | `true` | | `false` drops the dimmed backdrop. The backdrop fades in and out |
| `showClose` | boolean | `true` | | Shows the close button in the corner |
| `defaultFocus` | object, handle or function | | | What is selected when it opens on a keyboard or gamepad. A function is called with the dialog |
| `size` | string | `"md"` | | How wide it gets: `sm` (384), `md` (448), `lg` (512), `xl` (640) or `full` |
| `maxWidth` | number | | | The widest it gets in pixels, instead of `size` |
| `maxHeight` | number, ref or getter | | | The tallest it gets in pixels. The body scrolls past it |
| `onOpenChange` | function | | | Called with `(open, handle)` when it opens or closes |

It also takes the [props every component takes](index.md#using-a-component).
Without a `Parent`, it goes into the app's modal layer, above every scene. A
dialog opened later shows above one opened earlier.

When the content is taller than `maxHeight`, or than the screen, the body
scrolls and the title and actions stay where they are. So leave out a table's
`maxHeight` inside a dialog, unless the table should scroll on its own.

While a modal dialog is open, keyboard and gamepad focus stay inside it. When
it opens on a keyboard or gamepad, its last action (the main one) is selected,
or the close button when it has no actions; pass `defaultFocus` to pick
something else, such as the first item in a shop. When it closes, focus goes
back to whatever had it before. If that can't take focus any more, such as a
Buy button that disabled itself, the control nearest it is selected instead.
A dialog with
`modal = false` is still on top, but the rest of the screen keeps working,
and B or Backspace still closes it.

### Actions

Each action is a table with `text`, and optionally `variant`, `disabled` and
`onClick`. The last action defaults to `default` and the rest to `outline`.
An action closes the dialog after its `onClick` runs, unless `onClick` returns
`false` or the action has `close = false`.

## Methods

| Name | What it does |
|---|---|
| `dialog:open()` | Opens it |
| `dialog:close()` | Closes it |
| `dialog:toggle()` | Opens it if closed, closes it if open |
| `dialog.body` | The frame that holds `children` (hidden when there are none) |
| `dialog.scroll` | The [ScrollArea](scroll-area.md) around the body |

## Alert dialogs

`Lucy.Dialog.alert` asks a question with two buttons and opens straight away.
Clicking outside it does nothing and it has no close button, so the player has
to choose. Back (B or Backspace) picks Cancel; pass `backCancels = false` to make
it do nothing instead.

```luau
Lucy.Dialog.alert({
    title = "Delete this outfit?",
    description = "It leaves your Wardrobe for good.",
    confirmText = "Delete",  -- default "Continue"
    cancelText = "Keep",     -- default "Cancel"
    destructive = true,      -- a red confirm button
    onConfirm = deleteOutfit,
    onCancel = function() end,
})
```

Either button closes it after its function runs. An alert is used once: it is
destroyed when it closes, so call `Lucy.Dialog.alert` again each time you ask.

## Examples

Open a dialog from anywhere by its id:

```luau
app.state:set("ui.quit.open", true)
```

Keep the dialog open when a check fails:

```luau
Lucy.Dialog.new({
    title = "Name your crew",
    children = { Lucy.Input.new({ id = "crewName", placeholder = "Crew name" }) },
    actions = {
        { text = "Cancel", variant = "outline" },
        {
            text = "Create",
            onClick = function()
                local name = app.state:get("ui.crewName.value")
                if name == "" then
                    app.toast.error("Pick a name first")
                    return false -- stay open
                end
                createCrew(name)
            end,
        },
    },
    open = true,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Dialog")`.
