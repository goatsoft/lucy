# Lucy architecture

Lucy is a UI kit and small application framework for Roblox. This page is the
map; the ADRs in `docs/adr/` hold the reasoning.

## The pieces

```
App ─────────────── one per client, owns everything below
├─ AppState         single store: ui.<id>, scenes, toasts, input, theme, density   (ADR 0004)
├─ Theme            Universal Styling sheet graph + all StyleRules                 (ADR 0003)
│   └─ Tokens       OKLCH palette (via Oklab), light/dark themes, densities        (ADR 0010)
├─ InputManager     mode, device, focus ring, focus scopes, Tab nav, back          (ADR 0007)
├─ SceneManager     one ScreenGui per scene, layers, stack, overlays               (ADR 0005)
├─ Adaptive         UIScale per gui with device profiles, constraints, StyleQuery  (ADR 0006)
├─ portals          shared ScreenGuis: "modal" (900), "toast" (1000)
└─ toast            toast API, installed when Components/Toaster exists
```

Components (`src/Components`) are built on `Core/Component` (ADR 0002).

## Data flow

```
 game code ──write──▶ AppState ──notify──▶ component update() ──▶ Instance props + tags
     ▲                   ▲                                              │
     │                   │                                              ▼
     └──read──── handle:get()          Theme rules match tags ──▶ rendered style
```

- Components never hold UI truth locally; `ui.<id>` in AppState is the truth.
- Code changes **behaviour and layout** (Text, Visible, Size, Interactable, tags).
- Rules change **looks** (colours, fonts, radius, stroke, padding, heights).

## Styling

```
Folder Lucy_Styles (ReplicatedStorage)
├─ Tokens            palette + radius, space, fonts, stroke
├─ Theme_light/dark  semantic colours ($Primary, $Border ...), derives Tokens
├─ Density_default/touch/tv  ControlSm/Md/Lg/Icon, TextXs..Text4xl
└─ Design            derives ActiveTheme + ActiveDensity, holds every StyleRule
```

Every app ScreenGui has a `StyleLink` to `Design`. Rule priority bands:
reset -100 · base 0 · variant/size 10 · state 20 · disabled 30 · focus ring 100.

Tags are classes: `ui-<component>`, `ui-<component>-<key>-<value>` for variants,
`ui-disabled`, `ui-checked`, `ui-focused`, `ui-focus-visible` for flags.

Styled values are read with `instance:GetStyled(prop)`; plain reads return the
unstyled value. Styles apply a few frames after a change.

## Scenes and layers

| Layer | DisplayOrder | Shown | Examples |
|---|---|---|---|
| screen | 10 | exactly one (`scenes.current`) | Title, Lobby, Game |
| overlay | 100+ | any, independent (`scenes.visible`) | HUD, chat |
| modal | 200+ | stacked (`scenes.stack`) | Pause, Settings |
| portal: modal | 900 | dialogs | Dialog, Dialog.alert |
| portal: toast | 1000 | toasts | app.toast |

## Input and focus

`input.mode` follows the last input. `input.device` is derived from capabilities
(10-foot interface → console; touch only → mobile or tablet by short side;
otherwise desktop) and drives density and the adaptive profile.

Focus scopes stack: screens and modal scenes push one on enter, dialogs push one
while open. Keyboard Tab/arrows, gamepad selection and `defaultFocus` all work
inside the top scope. Escape / ButtonB call `app.input:back()`.

Roblox's own selection image is replaced with a blank frame; Lucy draws its own
ring with the `ui-focus-visible` tag only while navigating with keys or a pad.

## Folder layout

```
src/
  init.luau            package entry (Wally)
  Core/                framework; always installed
  Components/          one file per component + its spec
  Testing/Harness.luau shared test helpers
tests/Runner.luau      runs every spec, returns a summary
scripts/               add.luau (copy-in CLI), gen-palette.luau, run-tests.server.luau
registry.json          what the CLI can install and the dependencies
docs/                  this, development guide, components, ADRs
```
