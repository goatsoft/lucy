# 0024: One overlay layer for dialogs, sheets and popups

- Status: accepted
- Date: 2026-10-31
- Amends: 0007 (focus scopes return focus), 0021 (how Select and Sheet float)

## Context

ADR 0021 asks for Sheet and Select on "one floating layer that knows the
player's device": a sheet on touch, a popup on mouse, a list that holds focus
on gamepad. Today:

- Dialog mounts into the `modal` portal (display order 900) and keeps its own
  module counter so the newest dialog is on top.
- `App.portalOrder` has an unused `popover` portal at 800. Anything floating
  there would open underneath a dialog, so a Select inside a Dialog, or a
  confirm Dialog opened from a Sheet, would stack the wrong way.
- Popping a focus scope selects the next scope's default focus. When a popup
  closes, a gamepad player lands on the dialog's last action instead of the
  Select they opened it from.
- Nothing positions a frame next to another one, or keeps it on screen.

## Decision

### 1. One layer, stacked in open order

Dialogs, sheets and popups all mount into the `modal` portal and stack by the
order they opened: the newest is on top whatever its kind. The counter moves
from Dialog into `Core/Overlay.luau`. The `popover` portal order is removed.
Toasts stay above everything (1000).

### 2. `Core/Overlay`, internal

`Overlay.open(app, options)` is the one way to float something. It is not
exported (Popover stays internal, 0021); Sheet, Select and Dialog use it.

```luau
local overlay = Overlay.open(app, {
	content = frame,              -- what floats
	anchor = trigger,             -- popup: place next to this GuiObject
	presentation = "auto",        -- auto | popup | panel | drawer | center
	side = "bottom",              -- popup: bottom | top (flips when there is no room)
	align = "start",              -- popup: start | center | end
	panelSide = "right",          -- panel: left | right
	scrim = nil,                  -- dim backdrop; defaults by presentation, false for none
	modal = true,                 -- false: no focus trap, presses pass through
	dismissible = true,           -- back and outside press close it
	defaultFocus = fn,            -- what gamepad and keyboard select first
	onClose = fn,                 -- reason: "back" | "outside" | "anchor" | "code"
})
overlay:close()
```

`auto` is decided once, when it opens, from `input.mode`:

| Mode | Select | Sheet |
|---|---|---|
| touch | drawer (bottom, full width) | drawer |
| mouse, keyboard | popup (anchored) | panel (side) |
| gamepad | popup (anchored), holds focus | panel, holds focus |

It does not change while open: a layout that jumps when the player touches a
different device is worse than one that fits the last device a moment longer.
It does follow the viewport (rotation, resizing) while open.

Every presentation, on every device:

- pushes a back handler (Escape and B close it when `dismissible`);
- closes when its anchor is hidden, unparented or destroyed.

`modal` and `scrim` are separate, and both can be turned off for any
presentation, Dialog included (`modal = false`, `scrim = false` on Dialog and
Sheet):

- **modal** (the default): a focus scope (Tab, arrows and the stick stay
  inside), a SelectionGroup whose edges stop, and a full screen catcher so
  presses outside go nowhere but closing it. It counts toward modal input.
- **not modal:** no focus scope or catcher. Presses outside reach whatever is
  under them, focus can move between it and the rest of the UI, and it does
  not count toward modal input. It still stacks in open order. A press
  outside does not close it unless `closeOnOutside` is set.
- **scrim:** only the dim backdrop. A modal with `scrim = false` still blocks
  presses outside with a clear catcher; a non modal one has no catcher at all.

By presentation:

- **popup:** no scrim; when modal, a clear catcher closes it on a press outside.
  Placed below the anchor (or above, when there is less room below), aligned
  to it, at least the anchor's width, clamped inside the viewport with a
  margin. Height is capped by the room on the chosen side; the content
  scrolls (a ScrollArea) when longer.
- **drawer:** a scrim; slides up from the bottom, full width, height capped at
  a share of the viewport; respects the bottom safe area.
- **panel:** a scrim; full height on the chosen side, a width token, capped at
  a share of the viewport.
- **center:** a scrim; centred (Dialog).

### 3. Focus returns where it came from

`InputManager.pushScope` takes `returnFocus` (a GuiObject or a function). When
the scope pops and the player is navigating, focus goes to it if it is still
shown and interactable, otherwise to the next scope's default as today.
Overlay passes the anchor, or the focused object at the moment it opened.
Dialog gets this too.

### 4. State

The app publishes `overlay.count` (open overlays), `overlay.modal` (open modal
ones) and `overlay.top` (the newest one's id). Modal input (0021 step 6) builds
on `overlay.modal`, so a non modal panel never blocks movement or hotkeys.

### 5. Where step 4 goes from here

Overlay and the focus change first, with Dialog moved onto Overlay (its specs
unchanged). Then Sheet, Select and Dialog sizing. Separately, a ScrollArea is
`Selectable` when it has no selectable descendants, so the right stick scrolls
a body of plain text on gamepad.

## Consequences

- Stacking is correct whatever opens what: a Select in a Dialog, a Dialog from
  a Sheet.
- Gamepad players get back to the control they opened a popup from.
- One positioning and dismissal path to test instead of one per component.
- Dialog's defaults are unchanged apart from focus returning to its opener;
  it gains `modal` and `scrim`.

## Alternatives considered

- **A separate portal per kind** (popover 800, modal 900, or popover above
  modal). Either order is wrong for one of the nestings above.
- **Re-deciding the presentation when the input mode changes while open.**
  Rejected: the content would jump between a drawer and a popup under the
  player's thumb.
- **A public Popover now.** 0021 keeps it for later; Overlay stays internal so
  its options can change while Sheet and Select settle.
