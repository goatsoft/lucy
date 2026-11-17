# 0049: Mount on open

- Status: accepted
- Date: 2026-11-18

## Context

Lucy follows shadcn (ADRs 0002, 0003, 0006, 0009, 0010, 0042), and shadcn's
components sit on Radix. Radix builds a dialog's content when it opens and
removes it when it closes, and builds only the tab panel that shows; `forceMount`
keeps content built when a game needs it. Ark UI (`lazyMount`, `unmountOnExit`)
and Reka UI (`unmountOnHide`, default on) do the same.

Lucy never wrote this down, and went the other way: `Sheet.new` and `Dialog.new`
build their slots when they are made, `Tabs` builds every panel at mount
("built at mount and kept", for scroll position), `Collapsible` builds its
content at mount, and `Select` and `Menu` build their rows with the trigger. A
game that makes its panels when its modules load (Dance Lab does) builds every
sheet, dialog and tab it has before the player opens one.

Measured in Dance Lab (Studio, 2026-11-17):

- About 12,000 hidden instances in the modal portal at the start: the inventory
  sheet alone is 6,500 (three tabs, the whole GEAR list, 11 avatar copies), with
  the DJ booth, song picker, dance menu, settings, admin and more beside it.
- 3,722 live components, most in panels nobody has open. Their bindings keep
  running: wearing a new tee froze the game for 1.8 s because the hidden
  inventory's scroll area rescanned all of it (fixed in perf(scroll-area), but
  live hidden panels are the general problem).
- Hidden GuiObjects are not drawn, but every instance costs memory and time to
  create, and the whole build happens while the game starts.

Games have spent a lot of time on their sheets and dialogs. Lucy is not
published yet and Dance Lab is its only game, so the default is changed now,
before publishing locks it until 1.0 (JB, 2026-11-18), and every Dance Lab
sheet, dialog, tab, select and menu is checked against each step before Dance
Lab moves to it (Order of work, 5).

## Decision

### 1. Two kinds of component, two opt-ins

**Content-owning components (Tabs, Collapsible, Accordion, Select, Menu)** make
their content themselves, from a function (`content`) or a table (`items`). They
take `mount`:

- `mount = "shown"`, the default: built the first time it shows.
- `mount = "immediate"`: built when the component is made, as before this ADR. The way
  back for a component whose content must exist before it shows.

**Slot components (Dialog, Sheet)** hold content the game has already made
(`header`, `children`, `footer`, `corner`). There is nothing to defer unless the
game hands over a function, so the opt-in is that function, not a prop:

- Slots given: built now, exactly as before.
- `build` given: built on first open.
- Both: an error naming the slots to move into `build`.

`keep` (5) is valid with `mount = "shown"` or `build`; given with `mount = "immediate"`
or with slots it is an error (it would be ignored).

### 2. Dialog and Sheet: one `build` function

```luau
Lucy.Sheet.new({
	id = "inventory",
	title = "INVENTORY",
	build = function(sheet)
		local tabs = Lucy.Tabs.new({ id = "inventory-tabs", mount = "shown", items = { ... } })
		return { header = { tabs.bar, line }, children = { tabs } }
	end,
})
```

- One function makes everything once, so a component split across slots (Tabs:
  its bar in `header`, its panels in `children`, as docs/components/tabs.md and
  Dance Lab do) is made once and placed in both. No slot order to rely on.
- What it returns is placed in one fixed order, header, children, footer,
  corner, for both components.
- `build` gets a complete handle: `open`, `close`, `toggle`, `body`, `actions`,
  `bodyRoom` and the slot fields are attached before it runs, on both paths
  (open at mount and open later). Building happens in `X.new` after the handle
  is finished, never inside `render`.
- `actions`, the title, the close button and the empty shell (body, scroll area,
  slot frames with their layouts and padding) are built at mount as today, so
  `defaultFocus = function(d) return d.actions[1] end` still works.
- With `build`, what depends on the content is reactive instead of fixed at
  mount: Sheet's `headerSlot.Visible`, `footerSlot.Visible` and `hasFooter`
  (also read by `bodyCap`), and Dialog's body visibility. The slot-props path is
  left as it is, so its specs pass unchanged.

### 3. Built before anything sees "open"

Reactive `notify` marks observers in hash order. A builder watching `open`
beside `Overlay.use`, `useFocusScope` and `onOpenChange` could run after them,
and focus and placement would find an empty panel. So:

- `open` stays the state the world writes (`ui.<id>.open`, the MCP, `open()`).
- A `shown` accessor (`Reactive._accessor`): its getter is true once `open` is
  true and the content is built; its setter writes `open`. `Overlay.use` gets
  `shown` as `options.open`, and so do `useFocusScope` and the `onOpenChange`
  callback. Back, outside press and anchor loss close through the setter, so
  `ui.<id>.open` goes false as today.
- One watcher on `open` builds if needed, then sets the built flag `shown` reads.
- With nothing deferred (`mount = "immediate"`, slots), `shown` is the `open` ref
  itself.
- `open = true` at mount (`Dialog.alert`, `open = true` in props) builds right
  after the handle is finished in `X.new` (2), then sets the flag.
- A `build` that throws: `open` is written false, the error is reported, nothing
  half built is left, and the component can be opened again.
- Select and Menu's `defaultFocus` reads their rows, so they use the same
  `shown` order.

### 4. The build scope

Content runs in its own scope, made with `handle.scope:run(function() return
Reactive.effectScope() end)`. Never inside the `open` watcher: a watch callback
runs in a scope disposed on its next run, so anything made there would be
destroyed on close even with `keep = true`. `build` runs through
`scope:run(build, handle)`. `destroy` still ends everything through
`handle.scope`.

### 5. What closing does: `keep`

- `keep = true`, the default: built once, hidden on close, kept. Reopening is
  instant and keeps scroll position and typed text.
- `keep = false`: removed on close, built again on the next open. For big
  panels opened rarely (an admin sheet).
- Tabs: `keep = false` removes a panel when another tab shows.

Removal:

- Before `build`, each slot's children are noted. On removal the content's scope
  is stopped, then every child not in that note is destroyed. One rule covers
  elements, plain instances and a split `tabs.bar`, and leaves the slot's own
  layout and padding (`UIListLayout`, `UIPadding`, PanelCorner's slot). The
  body's `CanvasPosition` goes back to zero.
- `Overlay.use` returns `visible()` (`open() or closing()`). Removal waits for
  it to go false (after a drawer's 0.2 s slide) and checks it again before
  removing, so a quick reopen cancels it. Collapsible waits for `not open() and
  progress() == 0` the same way.
- Inner state goes with it: a component inside removed content is destroyed, and
  its `ui.<id>` with it unless it is bound to app state or made with `persist`.
  A rebuilt admin sheet starts on its first tab, empty, unless the game keeps
  those values in its own state. The component's own keys (`open`, a Tabs'
  `value`) stay.

### 6. Tabs specifics

- One `ensure(value)` builds a panel once. It is called from a watcher on
  `value` (a click on the tab bar, a `ui.<id>.value` write, a bound ref, and the
  first value set after render all go through it), at mount for the current
  value, and directly in `shoulder` (LB, RB) before it reads the new panel's
  selectables, so a `Lucy.batch` cannot delay it.
- `h.panels[value]` is the empty panel frame from the start.
- A deferred Tabs works inside an unchanged Sheet: it is the first step (Order
  of work, 1).

### 7. Menu: placement after measuring

Menu sizes itself from its measured rows (`fitWidth`, `GetTextBoundsAsync` in a
`task.defer`, read once by `place()`) and its arc captions from their
`AbsoluteSize`. Deferred rows are not measured when it opens, so `Overlay.use`
runs `place()` again when `options.width` (a getter) changes while open. The
deferred measuring checks the menu still exists and is built before reading a
label.

### 8. Building ahead: `handle:build()` and `Lucy.prebuild`

- `handle:build()` builds deferred content now, synchronously, without opening.
  A no-op when built or destroyed. Opening calls it.
- `Lucy.prebuild(handles)` builds them one handle per frame in its own queue,
  and returns a job with `done()` and `progress()`. It never splits a builder
  across frames (a builder cannot yield: Reactive tracks its owner in module
  globals while it runs). Opening a queued component builds it then; the queue
  skips it later. Destroyed handles are skipped. For a deferred Tabs it builds
  the panel that will show first.
- One frame still pays for a whole panel. The inventory's build time is measured
  and recorded here; if it is too long for one frame, the answer is deferred
  Tabs inside it, not splitting `build`.

### 9. Devtools and the MCP

Devtools lists only registered handles, so what is not built is not listed:
`press` and `tree` say it is not there, and opening builds it. `Devtools.tree`
gives a deferred component `built = false` and, for Tabs, `unbuilt = { values }`;
the MCP outline (libs/mcp outline.ts) prints the same.

### 10. Builder convention, deferred paths only

On deferred paths a builder is called as `builder(slot)`; what it parents to
`slot` stays, and a returned instance or handle is adopted into `slot` unless it
is already a descendant of it. `Component.adopt` and the `mount = "immediate"` and
slot paths are not touched, so they stay identical to before.

### 11. Guidance for games (docs and the agent skills)

- A panel module does nothing heavy when it is required: it makes its sheet or
  dialog with `build`, and registers its hotkeys and state. Requiring it is then
  close to free, so hotkeys and the MCP work from the start.
- `keep = true` for what players open often; `keep = false` for what they open
  rarely, with anything worth keeping in app state.
- `Lucy.prebuild` the panels players open first, once they are in.
- Pictures by how often a panel is used: what players open constantly is
  preloaded at the loading screen (`Lucy.preload` draws each picture once);
  what they open rarely is preloaded when its button is hovered or focused.

### 12. Built when scrolled near: `mount = "intersect"`

A long list in a panel that is showing is still built whole: Dance Lab's GEAR tab is
6,171 instances, and building it the first time the tab shows takes two long frames
(228 ms and 301 ms in Studio, against 66). Dance Lab's Club Pass board had its own
code for building a card when its column came near the screen. Lucy owns that now,
as a third value of `mount`, so no game writes it again:

- `mount = "intersect"` on a component that holds a list of children (**Stack**
  first, then Grid beside its `virtual`). A child given as a function is built the
  first time its place comes near the visible part of the ScrollingFrame around it.
  The name is the web's (IntersectionObserver): Lucy is for people who know the web.
- Each function child has a slot frame from the start (`handle.slots[i]`), holding
  `estimate` pixels along the stack until it is built, so unbuilt children are not
  all in view at once and the scroll bar does not jump. A game sets a child's
  `Visible` and `LayoutOrder` on its slot.
- "Near" is one view ahead and one behind (`Scroll.overscan`), so what a
  controller's next press lands on is already built. A hidden slot is not built.
  With no ScrollingFrame around it, a child is built when it shows.
- It is the same Core/Deferred part as Tabs: its own scope, `handle:build(i)` to
  build one ahead (a game that opens a list at an item far down builds that
  child first), Devtools `unbuilt = { indexes }`. Built children are kept;
  `keep = false` is refused with `"intersect"` until removing on the way out is
  needed and designed (the slot would have to hold its measured size).
- The looking is one function, `Scroll.whenNear(object, callback)`, under both
  the Stack prop and a composable, `Lucy.useIntersect(target, { enabled })`, for
  layouts that are not a Stack: the Club Pass board places its cards by hand on
  a track, each cell an element with `Lucy.show(reached, card)`. `enabled`
  holds the looking back until the track has been scrolled to the player's
  tier, or the cards at its start would be built for nothing.
- The default for Stack and Grid stays `"immediate"`: a function child is called at
  once, as before. Only content-owning components (1) default to `"shown"`.

The three values are `"immediate"`, `"shown"` and `"intersect"` (JB, 2026-11-18;
first written here as `"now"` and `"open"`).

## Order of work

Each step finishes its specs, docs, skills, Devtools and MCP outline before the
next starts. Each Lucy step that changes a default is checked in Dance Lab
before Dance Lab moves to it: nothing in Dance Lab may look or work differently.

1. The shared Core helper (scope, `shown`, the one watcher, `handle:build()`,
   removal by snapshot) and **Tabs**, default `"shown"`. Specs both ways.
2. **The first-frame check** in Dance Lab (Risk, below). Decide here whether a
   styling fix is needed before anything else defers.
3. **`build` on Dialog and Sheet**, with Overlay's `visible()` and `shown`.
4. **Collapsible and Accordion**, then **Select**, then **Menu** (with the
   re-place in 7), each default `"shown"`, specs both ways.
   Between 2 and 3 (JB, after step 2 showed GEAR's first show): **`"intersect"` on
   Stack** (12), GEAR's sections moved onto it, then the Club Pass board's own
   code replaced by it.
5. **Dance Lab**, with every step: before Lucy moves in vendor/Lucy, screenshots
   of every tab, select and menu it changes, before and after; focus checked
   with keys and a gamepad; the suite run; code that reached into an unshown
   panel or `h.items` fixed (an open or `handle:build()` first). Then its
   sheets and dialogs move to `build`, one panel at a time, checked the same way.

## Risk to measure first

**First open may show unstyled content.** Styles land a few heartbeats after an
instance is tagged. Today content is built long before it shows; deferred
content shows the frame it is built. That could mean a style flash on first
open, a drawer slide measured from the wrong height, or a Menu opening at 220 px
and then widening. Step 2 screenshots the first frame of a first open. If it
flashes, it is fixed in Lucy before steps 3 and 4 go on (built content waits a
frame for its styles before it shows, or `Lucy.prebuild` becomes required for
those panels).

## Consequences

- Tabs, Collapsible, Accordion, Select and Menu build on first show unless a
  game asks for `mount = "immediate"`. Dialog and Sheet change only for a game that
  gives `build`.
- A game that opts in starts with far fewer instances and live bindings and
  pays for a panel only when it opens.
- A deferred component's inner ids do not exist until it is built: code that
  reaches into a closed panel opens it, or calls `handle:build()`, first.
- Handle fields that point into content (`select.items`, `menu.items`,
  `menu.slices`) are nil until built; each component's page lists them.
- A game's own watcher on `ui.<id>.open` runs in hash order against the builder
  and can see "open" before the content exists; a game that needs the content
  watches `onOpenChange` (which follows `shown`) instead.
- Specs and game code that read `h.items` or reach into an unshown panel need
  an open or `handle:build()` first; each step fixes Lucy's own, and Dance Lab's
  before it moves (5).
- To measure, then record here: the first frame of a first open; the
  inventory's build time in one frame; instances and live components at the
  start, before and after; whether a kept, hidden panel still costs layout in
  the shared modal portal (ADR 0024). If it does, parking a closed kept panel in
  a disabled ScreenGui is next, and it must keep its theme link (no style flash
  on reopen), ignore placement while parked, respect a custom `Parent`, and wait
  for a drawer's slide out before moving.

## Alternatives considered

- **Other names for the third value.** `"view"`, `"visible"` (reads as `shown`, and
  as Roblox's `Visible`), `"inView"`, `"reached"`, `"onscreen"`, `"enter"` (a tile's
  `entered` state and the Enter key). `"intersect"` is exact and clashes with nothing.
- **A prop on ScrollArea that defers everything inside it.** The scroll area does not
  know which descendants are whole sections; the list that holds them does.

- **Keeping `"immediate"` as the default and flipping it later.** After Lucy is
  published the default is locked until 1.0, and every game would then have to
  change. Lucy has one game today, so it is changed now. Not applicable to
  Dialog and Sheet: their slots hold content the game already made, and a
  default of building on open would force `build` on every two-line confirm.
- **Deferring each slot prop (`header`, `children`, ...) separately.** Split
  components need two slots from one object, and Dialog and Sheet adopt slots in
  different orders. One `build` removes both problems.
- **A function in a slot means "build on open".** A builder already runs at
  once today (ADR 0042), so any game passing one would change behaviour.
- **A second watcher on `open` that builds.** Observers run in hash order; it
  could run after focus and placement. The `shown` accessor orders it for certain.
- **Building only in Tabs' `select` and `shoulder`.** A click on the tab bar,
  a state write and a bound ref never call `select`. A watcher on `value`
  catches all of them.
- **Lazy `require` of panel modules.** Hotkeys, state and the MCP need the
  module loaded, and with deferred content requiring it costs almost nothing.
- **One ScreenGui per overlay instead of the shared modal portal.** Breaks ADR
  0024's single stack in open order; with deferred content the portal only
  holds what is open or kept.
