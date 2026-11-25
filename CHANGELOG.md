# Changelog

What changed in each version of Lucy on Wally (`goatsoft/lucy`). The npm
packages keep their own: `libs/icons/CHANGELOG.md` and `libs/mcp/CHANGELOG.md`.

## 0.3.0

What a game has to change:

- **A failed `app.server:call` no longer carries the server's error text.** The
  reason stays on the server (in its output); the client only hears that the
  request failed. Show your own message from what `call` returns.
- **Every request now has a rate.** A handler made without `rate` gets 30 a
  second per player; a player who asks faster has the request dropped. Give
  busy handlers their own `rate`.

New:

- **Checked requests**: `server:handle(name, fn, { check, rate, unreliable })`.
  `check` lists a check per argument from the new **`Lucy.Check`** (`string`,
  `number`, `vector`, `instance`, `oneOf`, `optional`, `array`, `map`,
  `struct` and more), and the handler only runs when they all pass. `rate` is a
  token bucket per player. `Lucy.Server.new({ strict = true })` makes `check`
  required, so nothing reaches a handler unchecked, and `onReject` hears every
  dropped request.
- **An unreliable channel** for aim, effects and positions:
  `app.server:stream` to a handler made with `unreliable = true`, and
  `server:stream(player?, name, ...)` to `app.server:onStream(name, fn)`.
- **Cheaper syncing**: the shared state is compared once for every player, and
  `flushRate` sends it less often than every frame.
- **`Lucy.Profiles`**: players' saved data held by one server at a time on the
  data queue (session locking), so a trade then a quick server hop cannot
  duplicate items. Purchases are granted once with `profiles:receipt` (a grant
  gets a copy of the data and must not yield), trades are saved together with
  `Lucy.Profiles.commit`, and `profiles:close` saves everything on close.
- **`Lucy.Services`**: a game's modules started in the order they `need` each
  other, with a missing need or a loop named at start up.
- **`boards.get`** is checked and rate limited, so `Lucy.Boards` works on a
  strict server.
- A ready from a player who left is ignored, and repeated readies resend the
  whole state at most once every ten seconds.

## 0.2.0

- **Tooltip**: floating labels and cards attached to screen controls or world
  parts, with hover, focus, press, click, proximity, always and manual
  triggers, centred directional arrows, positioning options (`side`, `align`,
  `placement`, `sideOffset`, `alignOffset`, `avoidCollisions`,
  `collisionPadding`, `arrowPadding`), theme variants, custom variants and
  full `Lucy.Text` or custom component content.
- **Prompt**: a themed replacement for Roblox's `ProximityPrompt` with a
  circular `Kbd` key cap inside a circular `Progress` hold ring, nearest-prompt
  exclusivity, touch support, and `Prompt.restyle` / `Prompt.restyleOne` for
  existing `ProximityPrompt` instances.
- **Circular `Kbd` and `Progress`**: `Kbd` and `Progress` both support
  `shape = "circle"` (and `variant = "circle"`), so a circular key cap can sit
  inside a clockwise progress ring.
- **Text colour variants**: `Text` adds theme colour variants (`default`,
  `primary`, `secondary`, `destructive`, `success`, `warning`, `info`,
  `inverse`, `outline`, `overlay`), and explicit colour variants override a
  parent `Tooltip`'s variant colour.
- **Floating composables**: `useHover`, `useFocus`, `usePress`, `useDismiss`,
  `useDelayGroup` and `useProximity`, backed by `Core/Floating` and
  `World.positionOf`.
- **Fixes**: component state now tears down last when an outer effect scope
  stops, and stories register the docs icon sheet when needed.

## 0.1.0

The first release on Wally.

- Lucy's components, the App (scenes, app state, overlays, actions, and input
  for mouse, keyboard, gamepad and touch), themes on Universal Styling,
  reactivity, icons and Devtools. The docs at https://lucy.goatsoft.io cover
  each one.
- For games that used Lucy from source before this release, one change to the
  look: an App that picks no colours now starts in mauve greys with a violet
  primary, as on the website. `primary = "none"` gives the old black and white
  look. `Lucy.Tokens.spectrum` holds the mascot's magenta, orchid and sky to
  use as named colours.
