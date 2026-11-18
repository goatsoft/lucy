# 0050: Overlays mount the Radix way: a root, and a presence built on open

- Status: accepted
- Date: 2026-11-18
- Amends: 0049 (sections 1, 2 and 7: what a Dialog and Sheet build at mount, and Menu's placement
  after measuring), 0024 (where an overlay's layer is made)

## Context

ADR 0049 set out to follow Radix, where a dialog's content is built when it opens and removed when
it closes. It read "content" as what goes in a Dialog's or Sheet's slots, and kept the rest built
at mount: the overlay root, the scrim, the panel and its frame, the title, the description, the
close button, the scroll area, the slot frames and the actions (0049, 2: "the empty shell ... built
at mount as today"). Menu and Select did the same: their rows wait for the first open, their
overlay does not.

That is not what Radix does. In Radix, `Dialog.Root` holds state and nothing else. `Dialog.Portal`,
`Dialog.Overlay` and `Dialog.Content` are each wrapped in `Presence`, which mounts them only while
the dialog is open (or `forceMount` is set). The overlay, the panel, the title and the close button
are all inside that. The same holds for Popover, DropdownMenu and Select: their portal and content
mount on open, and the trigger is the only part that exists while closed.

Measured in Lucy (LucyTests, Studio, 2026-11-18), what a closed Dialog or Sheet with `build` still
costs:

- 46 instances (Dialog) and 48 (Sheet): Frame 18 to 20, UIListLayout 10, ScrollingFrame 2,
  TextLabel 4 (two of them the description marquee, made with no description), TextButton 3 to 4,
  UIGradient 3, and the rest.
- About 2 ms each to make, and up to about 130 KB of Lua heap each (the live bindings of a panel no
  one sees; the number includes garbage not yet collected, so it is a ceiling).
- No measurable frame time while hidden: a hidden frame is not drawn.

In Dance Lab that is 14 panels, about 650 instances and 25 to 30 ms at load, and the modal portal
at 718 instances in the club with every panel's content already built on open. A closed Menu still
holds its overlay root, scrim, content frame and scroll area.

Lucy is not published and Dance Lab is its only game, so the model is put right now, once, for every
overlay (JB, 2026-11-18).

## Radix, part by part, and Lucy

| Radix | What it does | Lucy |
| --- | --- | --- |
| `Root` (open, defaultOpen, onOpenChange, modal) | state only | the handle: `ui.<id>.open`, open/close/toggle, props, events. Made at once |
| `Trigger` | the button; focus returns to it | `anchor` and `returnFocus`, a game's own button. Unchanged |
| `Portal` (container, forceMount) | mounts its children into the body, only while present | the modal portal (`app:portal("modal")`, or `Parent`). The handle's Instance is an empty host frame there (one instance) |
| `Presence` | mounts while present; on close waits for the exit animation (unmountSuspended), then unmounts | the presence part (Core/Deferred): built on the first open, before anything sees it open (0049, 3). On close it waits for `visible()` (a drawer's slide, the scrim's fade) |
| `Overlay` | the inert backdrop, modal only | Overlay.use's root and scrim, inside the presence |
| `Content` | the panel; FocusScope + DismissableLayer | the panel and everything in it, inside the presence |
| `forceMount` | mounted while closed | `mount = "immediate"` |
| unmount on close (default) | Presence unmounts | `keep = false`. Lucy's default is `keep = true` (below) |
| `DismissableLayer` layers (one shared ordered set; only the highest handles Escape; lower layers ignore outside presses while a modal is above) | nested dialogs | the overlay stack (0024): entries in open order, the back stack (`InputManager.pushBack`, top only), outside presses closed only by the top modal's scrim. Unchanged: dialog on dialog stays |
| `FocusScope` stack (a new trapped scope pauses the one below, which resumes when it unmounts; focus returns to what had it) | nested focus | `InputManager.pushScope` (top only, `SelectionGroup` stops at the edges), `returnFocus`. Unchanged |
| `onOpenAutoFocus` / `onCloseAutoFocus` | where focus goes | `defaultFocus` / `returnFocus`. Unchanged |
| Select's closed content in a detached DocumentFragment, so items exist for the Value | the trigger shows the chosen text | Select's trigger reads the chosen item's text from `items` (data, not rows), so it needs no rows while closed |
| Tabs / Collapsible / Accordion content in `Presence` | built when shown | 0049's `mount = "shown"`. Unchanged |

What Roblox changes:

- There is no component tree beside the instance tree, so there is no Portal context: the host
  frame in the modal portal is the portal, and the presence builds under it.
- Exit animations are Lucy's own (the drawer's slide, the scrim's fade, `Overlay.visible()`), not
  CSS `animationend`.
- Escape is back: B, Backspace or Escape, through the back stack.
- `aria-hidden` and scroll locking have no Roblox counterpart. A modal's scrim takes presses, and
  `overlay.modal` in app state lets a game turn its hotkeys off.
- Focus is GuiService selection: a focus scope is a SelectionGroup that stops at its edges, not focus
  guards.

## Decision

### 1. Every overlay is a root and a presence

Dialog, Sheet, Menu and Select are made of two parts:

- **The root**, made by `X.new`: the handle, its state keys (`open`, `visible`), its methods
  (`open`, `close`, `toggle`, `select`, `build`), its props and events, its id in Devtools and the
  MCP, and one empty host frame in the modal portal (the handle's Instance). Nothing else, except
  for Select, whose root is also its trigger: the control on the screen that shows the value.
- **The presence**, made by `build`: Overlay.use (its root, scrim and catcher, its focus scope, back
  handler and outside presses), the panel or list with everything in it (frame, title, description,
  close button, scroll area, slots, actions, rows), and the content a game gives. It is one deferred
  part (Core/Deferred) with its own scope under the handle's, parented under the host.

### 2. When the presence is built: `mount`

All four take `mount` like the content-owning components (0049, 1):

- `mount = "shown"`, the default: built the first time it opens, before anything sees it open.
- `mount = "immediate"`: built when the component is made (Radix's `forceMount`).

This now holds for a Dialog or Sheet given slots too. Instances a game passes as slots are made by
the game; they wait, unparented, and are put in the slots when the presence is built. `build` on a
Dialog or Sheet stays as it is (0049, 2): one function that makes the content on the first open.
"Give build or the slots, not both" stays.

`handle:build()` builds the presence now without opening it, and `Lucy.prebuild` builds several, one
a frame (0049, 8).

### 3. Built before anything sees it open

0049, 3 applies to the whole presence: `open` is what the world writes, `shown` is true once the
presence is built and open, and Overlay.use, the focus scope, `onOpenChange` and the open event
follow `shown`. Overlay.use is called inside the presence's build, with `shown` as its `open`.

### 4. What closing does: `keep`

- `keep = true`, the default: built once, hidden on close, kept. Lucy keeps Radix's opt-in the other
  way round: a Roblox panel costs more to make than a DOM subtree, scroll position and typed text
  last, and Ark (`lazyMount` without `unmountOnExit`) does the same.
- `keep = false`: the whole presence is removed once it has left the screen (after
  `Overlay.visible()` goes false), and built again on the next open. Only the root and its host
  frame stay.

### 5. Reaching into an overlay: `onBuild`

Every handle field that points into the presence is nil until it is built: `frame`, `content`,
`body`, `overlay`, `scrim`, `headerSlot`, `footerSlot`, `actionsRow`, `actions`, `closeButton`,
`titleLabel`, `shadow`, `plate`, `cornerSlot` (Dialog and Sheet), `content`, `items`, `slices`
(Menu), `content`, `items` (Select). Each component's page lists them.

A game styles or reaches into them in `onBuild = function(handle)`, which all four take. It runs once
the presence exists, each time it is built, inside the presence's scope, before it shows. Menu's
`onBuild` (0049, 7) becomes this. For a Dialog or Sheet with `build`, onBuild runs after build's
content is placed. With `mount = "immediate"` it runs when the component is made.

`defaultFocus`, `returnFocus` and `onOpenChange` keep working as they are: they run while open, when
the presence exists.

### 6. The first frame of a first show

A presence built as it opens shows the frame it is built. Text and automatic sizes are measured in
the layout after it, so anything placed from measured sizes (a Menu fan's labels, a drawer's height,
a popup's width) would show placed wrong for that frame. Overlay.use, made by a presence that is
built as it opens, places its content at `Overlay.offscreen` until the Heartbeat after the next
drawn frame, then places it for its measured size and starts its slide or fade. Focus, the open
event and `onOpenChange` do not wait. Menu's own version of this (dbeef70) moves into Overlay. A
presence built ahead (`build()`, `prebuild`, `mount = "immediate"`) is measured on its first show
the same way.

### 7. Nested overlays

Unchanged (0024): a dialog opened from a dialog, a menu from a sheet, a select in a dialog, each
goes on top of the stack in the order it opened. Only the top one handles back and outside presses;
the focus scope below pauses and is resumed when the top one closes. A presence is built before its
entry joins the stack, and a removed presence leaves the stack before it is destroyed.

### 8. Smaller parts inside the presence

The description marquee is made only when there is a description (a string, a ref or a getter).
The corner and its slot only when there is something for it.

### 9. Devtools and the MCP

The root is registered when it is made, so `tree`, `press`, `set ui.<id>.open` and hotkeys work from
the start. A root whose presence is not built lists `built = false` and no children; the MCP outline
prints `(not built)`. Opening builds it.

## Order of work

Each step finishes its specs (both mounts, both keeps, nested), docs, skills, Devtools and MCP
outline before the next, and is checked in Dance Lab before Dance Lab moves to it: nothing may look
or work differently.

1. **Core**: the presence part (Deferred, with the host), Overlay.use called from a presence, the
   first-frame placement (6), a removed presence leaving the stack.
2. **Dialog**, then **Sheet**: the root and presence, `mount`, `keep` on the whole, `onBuild`, the
   description and corner only when used.
3. **Menu**, then **Select**: the overlay into the same presence as the rows; Menu's own settle code
   removed.
4. **Dance Lab**, panel by panel, with the two-run check (screenshots, frame-by-frame probe, focus
   with keys and a gamepad, the suite, a clean console): every `tonePanel`, the intro's green
   buttons and every other line that reaches into a panel at load move into `onBuild`.
5. Measure and record here: instances in the modal portal at club start and on the title screen,
   live components, Lua heap, before and after.

## Consequences

- A game that makes its panels when its modules load pays for the root and one host frame each,
  until a player opens one.
- Code that reaches into a closed overlay's parts moves into `onBuild`, or calls `handle:build()`
  first.
- A Dialog or Sheet given slots now builds its panel on first open too. A game that needs it built
  says `mount = "immediate"`.
- `keep = false` frees everything but the root, so a panel seen once (an intro) costs almost nothing
  after.

## Alternatives considered

- **Building only the content (0049 as written).** Leaves about 46 instances and the live bindings of
  every closed panel, and is not what Radix does.
- **Making the shell cheaper while keeping it built** (fewer frames, no description marquee).
  Saves a third at most and keeps the wrong model.
- **Radix's default of removing the presence on close.** Rebuilding a Roblox panel on every open
  costs a frame or more for a big one, and loses scroll position and typed text; `keep = false` is
  there for panels seen rarely.
- **One overlay at a time.** Dance Lab opens dialogs over sheets and dialogs over dialogs, and Radix's
  layers allow it; the stack stays.
