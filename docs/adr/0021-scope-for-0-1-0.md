# 0021: What 0.1.0 ships: the Dance Lab test and the component list

- Status: accepted
- Date: 2026-10-31

## Context

Lucy will not be published on Wally until a real game has been built on it.
Roblox Dance Lab (about 12,000 lines of client UI, its own app state machine and
dialog manager, server built boards in the venue) will move all its UI and app
state to Lucy. The rule for that rebuild: Lucy only gets bug fixes while Dance
Lab is rebuilt, so every core component it needs must exist first. Pieces only
Dance Lab has (the hype meter, rhythm lanes, judgement effects, the choreography
timeline, its 3D previews, podium and roster slots) are built in the game, with
Lucy.

Lucy follows the shape of a well known web component kit, but every component
has to work on mouse, touch, gamepad and TV. Some of that kit's components
depend on hover or a pointer, or are not game UI at all.

## Decision

0.1.0 ships, on top of what exists (Badge, Button, Checkbox, Dialog, Input,
Panel, Pressable, Progress, Separator, Skeleton, Stack, Switch, Text, Toaster):

- **Layout and display:** ScrollArea, Grid, Item (a list row), Image and Icon,
  Avatar (a player headshot, a monogram for bots), Kbd and key hints (the right
  key for the device, none on touch; a `hint` prop on Button), Alert, Spinner,
  Table (leaderboards).
- **Selection:** Toggle, ToggleGroup, Tabs, RadioGroup, Select.
- **Overlays:** Sheet (a side panel; a bottom drawer on touch), Dialog sizing
  (a size or maximum height and a scrolling body). Select and Sheet share one
  floating layer that knows the player's device: a sheet on touch, a popup on
  mouse, a list that holds focus on gamepad.
- **Controls:** Slider (left and right on gamepad), NumberField, Accordion and
  Collapsible, Input options `multiline`, `numeric` and `maxLength`.
- **App:** modal input (a reactive "a modal is open", and blocking movement,
  jumping and hotkeys while one is).
- **Composables:** `useCountdown(endsAt)`, `useWhile(condition, setup)`;
  `useDrag` if the rebuild needs it. `useUiSound` shipped with 0020.

Later: Tooltip (on focus only), Carousel, Field, Empty, Dropdown Menu, and a
public Popover.

Not planned: context menus, menubars, hover cards, navigation menus, command
palettes, comboboxes, calendars and date pickers, data tables, charts,
resizable panes, sidebars, breadcrumbs, one time code and tag inputs, code
blocks and chat parts.

Still to design before building: registered variants (0022) and world UI
(SurfaceGui and BillboardGui: client or server, clickable surfaces, no screen
scaling).

## Consequences

- Every new component comes with a spec, a story, a docs page, a row in the
  components index, the README list and the count on the site.
- `useAppState` is not added: `app.state:ref(path)` already returns a tracked,
  writable ref with nothing to clean up.
- Publishing on Wally waits for the owner to call 0.1.0 once Dance Lab runs on
  Lucy.

## Alternatives considered

- **Publishing first and filling gaps from game feedback.** Rejected: a public
  API changed during a rebuild breaks the games that adopted it.
- **Porting the whole web kit.** Rejected: pointer only components do not work
  on gamepad, touch or TV, and would be the first things players hit.
