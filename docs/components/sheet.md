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

<!-- preview solo -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-sheet-light.webp" alt="Sheet example" loading="lazy"><img class="example-dark" src="/images/examples/components-sheet-dark.webp" alt="Sheet example" loading="lazy"></figure>

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
| `corner` | table | | | Instances or handles in the top right corner, left of the close button, such as a currency chip. See [The corner](#the-corner) |
| `children` | table | | | Instances or handles to put in the scrolling body |
| `footer` | table | | | Instances or handles under the body, above the actions. They stay put while the body scrolls |
| `build` | function | | | In place of `header`, `corner`, `children` and `footer`: makes the content when the sheet is built. See [Building on open](#building-on-open) |
| `mount` | string | `"shown"` | | When the sheet is built: `"shown"` the first time it opens, `"immediate"` when it is made |
| `keep` | boolean | `true` | | `false` takes the whole panel away once the sheet has closed and builds it again on the next open. With `mount = "shown"` only |
| `onBuild` | function | | | Called with the sheet once its panel exists, each time it is built, before it shows: the place to style or reach into it. See [Reaching into a sheet](#reaching-into-a-sheet-onbuild) |
| `preload` | list or function | | | Its pictures, or a function returning them, read when needed. Warmed by `warm()`, and first in the queue when it opens. See [Warming ahead](dialog.md#warming-ahead) |
| `trigger` | button, handle or list | | | What opens it. Hovered or focused, it warms (it does not open) |
| `ahead` | overlays or function | | | Overlays warmed when this one opens, such as a sheet opened from inside it |
| `side` | string | `"right"` | | `left` or `right`: the edge the panel comes from |
| `dock` | string | | | A name: sheets with the same dock open side by side from the edges, each at its `side`, the newest at the edge pushing the others over. One dock is open at a time. See [Side by side](#side-by-side) |
| `dockPin` | boolean | `false` | | With `dock`: holds this sheet at its edge; sheets opened after it open inward beside it |
| `dockSlide` | boolean | `true` | | With `dock`: `false` opens and closes the docked sheet immediately without sliding |
| `minWidth` | number | `width` | | With `dock`: how narrow the sheet may go when the screen is short of room; it then scrolls sideways |
| `scroll` | boolean | `true` | | `false`: the body does not scroll; it is as tall as the room the sheet has, and the children choose what scrolls (a ScrollArea with a `UIFlexItem` set to Fill takes what is left) |
| `width` | number | `360` | | The panel's width in pixels, at most 90% of the screen |
| `presentation` | string | `"auto"` | | `auto`, `panel` or `drawer` |
| `fill` | boolean | `false` | | Always as tall as it may be, whatever the body holds, so a sheet with tabs never grows or shrinks between them (a drawer on touch most of all) |
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
| `sheet:build()` | With `build`: builds the content now, without opening. Does nothing once it is built |
| `sheet:warm()` | Warms its pictures and builds it ahead, without opening. See [Warming ahead](dialog.md#warming-ahead) |
| `sheet.presentation()` | `"panel"` or `"drawer"`, for this opening |
| `sheet.body` | The [ScrollArea](scroll-area.md) that holds `children` |
| `sheet.bodyRoom()` | The height the body may take before it scrolls, in the sheet's own units. It follows the screen, the header and the footer |
| `sheet.headerSlot` | The frame that holds `header` |
| `sheet.cornerSlot` | The frame that holds `corner` |
| `sheet.footerSlot` | The frame that holds `footer` |
| `sheet.content` | The panel or drawer itself |
| `sheet.frame` | The clear frame round it that the overlay places, with the shadow and the plate |
| `sheet.shadow` | The shadow behind it (`ui-sheet-shadow`, shown when the `PanelShadow` token is above 0) |
| `sheet.plate` | The plate the title stands on, with `titlePlacement = "edge"` (else `nil`) |

## Building on open

A sheet is built the first time it opens. Until then only the sheet itself
exists: its id, `ui.<id>.open`, its methods and one empty frame in the modal
layer. The panel, its title, close button, body, slots and actions, and what
goes in them, are made on the first open, before anything treats the sheet as
open: it is placed, takes focus and calls `onOpenChange` after. A game with a
dozen sheets pays for none of them until a player opens one.

Content you made yourself and gave as `header`, `children` and the other slots
waits until then. To make the content on the first open too, give one `build`
function in place of the slots:

```luau
local inventory = Lucy.Sheet.new({
    id = "inventory",
    title = "Backstage",
    build = function(sheet)
        local tabs = Lucy.Tabs.new({
            items = {
                { value = "outfits", text = "Outfits", content = buildOutfits },
                { value = "drinks", text = "Drinks", content = buildDrinks },
            },
        })
        return { header = { tabs.bar }, children = { tabs } }
    end,
})
```

- `build` is called with the sheet each time it is built. What it returns goes
  into the slots in the order `header`, `children`, `footer`, `corner`, so
  something made once (tabs: the bar in the header, the panels in the body) is
  placed in both. `build` together with a slot is an error. If `build` throws,
  the sheet closes again and the error is reported.
- Once built, the sheet is kept: opening again is instant and finds it as the
  player left it. `keep = false` takes the whole panel away after it has closed
  (after a drawer has slid away) and builds it again next time. Use it for a sheet players see
  once or seldom, and keep what must last in [app state](../guide/app-state.md).
- `mount = "immediate"` builds it when it is made, for code that must reach
  its parts at once.
- `sheet:build()` builds it ahead without opening, and
  `Lucy.prebuild({ inventory, settings })` builds several, one each frame, so
  the panels players open first are ready by the time they do.
- The first time it shows, it waits one frame off the screen while its text is
  measured, then appears where it belongs (a drawer slides in from its
  measured height). Focus and `onOpenChange` do
  not wait.

### Reaching into a sheet: `onBuild`

The fields that point into the panel (`frame`, `content`, `body`,
`headerSlot`, `footerSlot`, `cornerSlot`, `actionsRow`, `actions`,
`closeButton`, `titleLabel`, `shadow`, `plate`) are `nil` until it is built,
and so are the components inside it. Style them or reach into them in
`onBuild`, which is called with the sheet once they exist, each time it is
built, before it shows:

```luau
Lucy.Sheet.new({
    id = "shop",
    title = "Shop",
    build = buildShop,
    onBuild = function(sheet)
        Lucy.hydrate(sheet.content)({ Tags = { "my-shop-panel" } })
    end,
})
```

Code elsewhere that reaches into a sheet that has never opened calls
`sheet:build()` first.

A module that makes its sheet this way costs almost nothing to require, so its
hotkeys and state can be set up when the game starts.

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

## Side by side

Give sheets the same `dock` and they open next to each other instead of on top
of each other. Each slides in at the edge of the screen and pushes the ones
already open over by its width; when it closes it slides out and they slide
back. The newest is always at the edge. A player can use them all at once:
there is one backdrop for the dock, the gamepad moves from one sheet to the
next, Back closes the newest, and a press outside closes them all.

The coat check in Club Lucy: the locker opens on its own at the counter, and
opening your backpack while it is open slides the backpack in at the edge and
pushes the locker over, so you can move things between them.

```luau
local locker = Lucy.Sheet.new({
    id = "locker",
    title = "Locker",
    dock = "coat-check",
    width = 320,
    children = lockerSlots,
})
local backpack = Lucy.Sheet.new({
    id = "backpack",
    title = "Backpack",
    dock = "coat-check",
    width = 420,
    children = backpackSlots,
})

locker:open()
backpack:toggle() -- the locker slides over to make room
```

Each sheet docks to its own `side`, so a dock can have sheets on both edges with
one backdrop and one focus scope. At an edge the newest sheet sits outermost and
pushes the others in; a sheet with `dockPin = true` holds its place and sheets
opened after it open inward beside it (a menu and its sub-sheets). Opening a
sheet in one dock closes the app's other docks. Docked sheets are always panels,
on touch too, and with reduced motion (or `dockSlide = false`) they appear and
move without sliding.

```luau
local menu = Lucy.Sheet.new({ id = "menu", dock = "menu", side = "left", dockPin = true, width = 280 })
local settings = Lucy.Sheet.new({ id = "settings", dock = "menu", side = "left", width = 420 })
menu:open()
settings:open() -- opens beside the menu; the menu stays at the edge
```

On a small screen the open sheets share the width. When they do not fit, they
give way (unpinned before pinned, the oldest first) down to each sheet's
`minWidth`, and a squeezed sheet scrolls sideways. Nothing is scaled down, so
what is sized for touch stays that size. A frame kept with `app:keep(frame)`
(the player's health, say) stays in sight above the dock, and a sheet under or
over it stops short of it. While dragging inside a sheet, call
`Lucy.Scroll.edge(sheet.frame, point, dt)` every frame to scroll toward an edge
the pointer is near.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Sheet")`.

## The corner

As on a [dialog](./dialog.md#the-corner), the close button keeps the top right
corner, in the same place and at the same size on every panel, and the `corner`
slot puts more on its left.

<!-- preview solo -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-sheet-2-light.webp" alt="Sheet example" loading="lazy"><img class="example-dark" src="/images/examples/components-sheet-2-dark.webp" alt="Sheet example" loading="lazy"></figure>

```luau
local coins = Lucy.Badge.new({ text = "1,250", icon = "lucide-extended:coins-filled" })
local bag = Lucy.Sheet.new({
    title = "Inventory",
    titlePlacement = "edge",
    corner = { coins },
    header = {
        Lucy.Tabs.new({
            variant = "line",
            items = {
                { value = "gear", text = "Gear" },
                { value = "potions", text = "Potions" },
            },
        }).bar,
    },
    children = { Lucy.Text.new({ text = "Everything you own.", variant = "muted" }) },
})
bag:open()
```
