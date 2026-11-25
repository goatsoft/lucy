# 0057: Floating content: tooltips and prompts

- Status: accepted (JB, 2026-11-25)
- Date: 2026-11-25
- Amends: 0021 (Tooltip was "after 0.1.0, on focus only")

## Context

Games want two things that float next to something else:

- a **tooltip**: a short label, or a small card, beside a button or over a part in
  the world, shown on hover, focus, a press, nearness, or always;
- a **prompt**: Roblox's ProximityPrompt, but drawn with Lucy: the key for the
  player's device, what it does, a ring that fills while it is held.

Web libraries split this the same way. shadcn-vue (on Reka UI) has a provider for
the shared delay, a root that owns `open`, a trigger and the content with `side`,
`align` and `sideOffset`, its looks in variants. Floating UI keeps **where** apart
from **when**: `computePosition` with middleware (offset, flip, shift, arrow, hide)
places the "floating" element by its "reference", and interactions (`useHover`,
`useFocus`, `useClick`, `useDismiss`, a delay group, a safe polygon for the gap)
decide when it opens.

Lucy already has the overlay layer (0024), world guis (0032), Actions and Kbd (0026)
and Text. `Overlay.place` puts a popup beside its anchor, but at least as wide as the
anchor, which suits a Select list and not a tooltip, and it has no arrow or offset.

## Decision

### 1. `Core/Floating` places; composables decide when

`Core/Floating` (internal) places floating content by a reference:

- `Floating.compute(input)`: pure. Side and align, an offset, flip to the other side
  when there is more room, shift along the side to stay on screen, and where an arrow
  sits so it still points at the reference after a shift.
- `Floating.use(app, options)`: a GuiObject reference floats in the overlay layer
  (`Overlay.use` with `presentation = "popup"`, not modal, no scrim, its own `place`),
  so tooltips stack with dialogs and follow the reference while open. A BasePart,
  Attachment or Model reference floats in a BillboardGui (`World.billboard`), its
  offset in studs from the side.

When it opens comes from composables, one file each (0054), which games can use on
their own too:

| Composable | Open while |
|---|---|
| `useHover` | the pointer is over the reference (or the content, when it is interactive) |
| `useFocus` | gamepad or keyboard focus is on the reference |
| `usePress` | held down (`"hold"`), or between one press and the next (`"toggle"`) |
| `useProximity` | the character is within a distance of a part, with a little more to leave |
| `useDismiss` | (closes) Back, or a press outside |
| `useDelayGroup` | (shared) the open delay, skipped while another tip was just open; one open at a time |

Each returns a small object with a tracked `active()` and methods to drive it
(`enter`, `leave`, `check`), so specs run without real input.

Overlay's `anchor` option keeps its name: inside Floating the thing it floats by is
the `reference`, as Floating UI calls it.

### 2. `Tooltip`

A component with `trigger` (hover, focus, press, toggle, always, proximity, manual,
or a list), placement props, variants and sizes in style rules, an arrow (a turned
square under the body, sharing its fill and stroke), and either `text` (a Lucy Text,
with any Text option through `textProps`) or `content` (a slot: any Lucy component).
`open` lives at `ui.<id>.open`. Hover adds focus on gamepad and a long press on touch,
so a tip is never out of reach.

### 3. `Prompt`

A component for interacting with something in the world: an action (Kbd shows its
key for the device), action and object text, a hold ring, and `exclusive`, so only
the nearest prompt for an action is live. `Prompt.restyle(app, options)` draws
every Roblox ProximityPrompt (Style set to Custom) with Lucy, keeping the server's
`Triggered`, holds and line of sight as they are.

## Consequences

- Tooltip moves out of "after 0.1.0". Tooltips on gamepad open on focus, as 0021
  asked, and proximity and always work on every device.
- Nearness is measured from the local character's root part, in a single Heartbeat
  loop per app shared by every user of `useProximity`.
- A Lucy Prompt is client only: `onTrigger` runs on the client, and a game tells its
  server through its own remote or `app.server`. Games that want the server to own
  the interaction keep real ProximityPrompts and use `restyle`.

## Alternatives considered

- **One module with a trigger state machine.** Rejected: harder to test, and a game
  that wants "show my own panel when near" would have no piece to reuse.
- **`Core/Anchor` or `Core/Popup`.** Rejected: Overlay already has an `anchor` option
  and a `"popup"` presentation.
- **Reusing the big Arrow component as the tooltip's arrow.** Rejected for the arrow
  itself (it grows and bounces); a tour pointer can still use Arrow beside a Tooltip.
- **Only restyling ProximityPrompts.** Rejected: a game with no server code for a
  prompt, or one that wants a tooltip that turns into a prompt, should not need an
  instance in the workspace.
