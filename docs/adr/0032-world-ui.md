# 0032: World UI on the client, made by the App

- Status: accepted (JB, 2026-11-01)
- Date: 2026-11-01

## Context

ADR 0021 left world UI (SurfaceGui and BillboardGui) to design before 0.1.0:
client or server, clickable surfaces, no screen scaling. The Dance Lab rebuild
(ADR 0021) needs it for the stage jumbotron, the title jumbotron overlay,
roster slots and stage billboards.

What we know about Roblox world guis:

- A SurfaceGui or BillboardGui parented to a part in the Workspace draws, but
  only takes clicks when it is in the player's PlayerGui with its `Adornee`
  set to the part.
- A gui the server makes replicates to every client and can only show what
  the server writes into it. Lucy has no server half (yet), and the store,
  bindings and components only exist where an App runs: the client.
- Screen scaling (Core/Adaptive, a UIScale per gui) fits a 1280 by 720 layout
  to the screen. A world gui's size comes from the part (pixels per stud or a
  fixed canvas) or the billboard's size, so screen scaling would be wrong.
- Universal Styling links any LayerCollector with a StyleLink, so
  `Theme.link` already themes a world gui.

## Decision

- `app:createSurface(name, options)` makes a SurfaceGui and
  `app:createBillboard(name, options)` a BillboardGui, in `Core/World`, beside
  `createGui`.
- Each goes in the App's parent (PlayerGui on a client) with `Adornee` set to
  the part (or, for a billboard, an attachment), so mouse and touch clicks
  reach it. `Active` is on.
- Each is linked to the theme, so components and `$Token` rules work as on
  screen. Neither gets a UIScale: options set the size in the world
  (`pixelsPerStud`, default 50, or `canvasSize`; `size` and `studsOffset` for
  billboards).
- World guis are not lit by the world unless asked (`lightInfluence` 0), so
  theme colours read the same as on screen.
- A world gui goes when its part leaves the DataModel and with the App (the
  App's maid), unlike `createGui`, whose guis are the caller's.
- World guis are not navigation targets: `App.activeGuis` lists screen guis
  only. Gamepad players reach world UI through a hotkey or ProximityPrompt that
  opens a screen UI.
- The server keeps its own data and publishes it; the client draws. A gui the
  server already made can be themed from the client with `app.theme:link(gui)`
  and bound with `Lucy.hydrate`.
- Density still follows the device. A touch player gets taller controls on a
  surface too, which suits tapping.

## Consequences

- World UI is client only. What the server knows has to reach the client,
  today as attributes or remotes; a server half for the store is a separate
  decision.
- Devtools sees components in world guis like any other.
- Docs: a "UI in the world" guide; `app.md` lists both methods.

## Alternatives considered

- **A world layer in SceneManager.** Rejected: scenes are one ScreenGui each
  with focus scopes and display orders; world guis have neither.
- **Server-made guis themed by the server.** Rejected: styling and bindings
  run where the App runs, and the server has no App.
- **Screen scaling on world guis.** Rejected: the part sets the size.
