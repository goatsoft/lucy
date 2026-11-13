<!-- Made by scripts/skills.ts from docs/components/sheet.md. Edit the doc, not this file. -->
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
    title = "Club settings",
    description = "Saved to your profile.",
    children = {
        Lucy.Switch.new({ id = "lights", label = "Light show", checked = true }),
        Lucy.Switch.new({ id = "hints", label = "Show dance hints" }),
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
| `header` | table | | | Instances or handles under the title, such as filters. They stay put while the body scrolls |
| `children` | table | | | Instances or handles to put in the scrolling body |
| `footer` | table | | | Instances or handles under the body, above the actions. They stay put while the body scrolls |
| `side` | string | `"right"` | | `left` or `right`: the edge the panel comes from |
| `width` | number | `360` | | The panel's width in pixels, at most 90% of the screen |
| `presentation` | string | `"auto"` | | `auto`, `panel` or `drawer` |
| `titlePlacement` | string | the `PanelTitleEdge` token | | `"inside"`, or `"edge"`: the title on a plate standing on the top edge, as a [Dialog's](dialog.md#the-frame); the room for it comes off the panel's top |
| `dismissible` | boolean | `true` | | Whether B, Backspace, a press outside and the close button can close it |
| `closeOnOverlay` | boolean | `true` | | Whether clicking outside closes it (off by default when `modal` is `false`) |
| `modal` | boolean | `true` | | `false` lets clicks reach what is behind it and lets focus move out of it |
| `scrim` | boolean | `true` | | `false` drops the dimmed backdrop. The backdrop fades in and out |
| `showClose` | boolean | `true` | | Shows the close button in the corner |
| `defaultFocus` | object, handle or function | | | What is selected when it opens on a keyboard or gamepad, instead of the first thing in the body. A function is called with the sheet. A non modal sheet takes focus only when this is given |
| `returnFocus` | object, handle, getter or `false` | | | Where keyboard and gamepad focus goes when it closes, in place of what opened it. `false` leaves nothing selected, for a menu or panel opened from a HUD whose buttons must not keep the left stick |
| `onOpenChange` | function | | | Called with `(open, handle)` when it opens or closes |

It also takes the [props every component takes](index.md#using-a-component).
Without a `Parent`, it goes into the app's modal layer, above every scene, and
shows above anything opened before it.

With `presentation = "auto"`, the shape is picked each time the sheet opens: a
drawer from the bottom when the player last used touch, a panel from the side
otherwise. It keeps that shape until it closes, even if the player switches
input while it is open.

A drawer slides up when it opens and back down when it closes; with reduced
motion it just appears. Its background runs to the bottom of the screen, and on
a phone with a home bar it leaves room above that bar, so the last row and the
actions stay clear of it.

The title, the `header` and `footer` slots and the actions stay where they are;
only the body between them scrolls, in whatever height they leave.

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
| `sheet.bodyRoom()` | The height the body may take before it scrolls, in the sheet's own units. It follows the screen, the header and the footer |
| `sheet.headerSlot` | The frame that holds `header` |
| `sheet.footerSlot` | The frame that holds `footer` |
| `sheet.content` | The panel or drawer itself |
| `sheet.frame` | The clear frame round it that the overlay places, with the shadow and the plate |
| `sheet.shadow` | The shadow behind it (`ui-sheet-shadow`, shown when the `PanelShadow` token is above 0) |
| `sheet.plate` | The plate the title stands on, with `titlePlacement = "edge"` (else `nil`) |

## Examples

Open a sheet from anywhere by its id:

```luau
app.state:set("ui.settings.open", true)
```

The Crew list on the left, leaving the dance floor playable behind it:

```luau
Lucy.Sheet.new({
    title = "Crew",
    side = "left",
    modal = false,
    scrim = false,
    children = crewRows,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Sheet")`.
