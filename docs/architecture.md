---
title: Architecture
description: How App, AppState, Theme, scenes and input fit together.
order: 1
---

# Lucy architecture

Lucy is a UI and app framework for Roblox. This page shows how its parts
fit together.

## The pieces

```
App ─────────────── one per client, owns everything below
├─ AppState         one tree of tables: ui.<id>, scenes, toasts, input, theme
├─ Theme            Universal Styling sheet graph + all StyleRules
│   └─ Tokens       OKLCH palette (via Oklab), light/dark themes, densities
├─ InputManager     mode, device, focus ring, focus scopes, Tab nav, back
├─ SceneManager     one ScreenGui per scene, layers, stack, overlays
├─ Adaptive         UIScale per gui with device profiles, constraints, StyleQuery
├─ portals          shared ScreenGuis: "modal" (900), "toast" (1000)
└─ toast            toast API, installed when Components/Toaster exists
```

Components (`src/Components`) are built on `Core/Component` and render with
`Core/Element`. Shared component behaviour lives in
`src/Composables` (`Lucy.use*`). `Core/Preview` mounts stories into their own App
for previewing.

## Data flow

```
 game code ──write──▶ AppState key ──changed──▶ the bindings that read it ──▶ Instance props + tags
     ▲                (ui.<id>.<key>)                                                  │
     │                                                                                 ▼
     └──read── handle:get(), app.state:ref()            Theme rules match tags ──▶ rendered style
```

- Components never hold UI truth locally; `ui.<id>` in AppState is the truth.
- A write to a key runs only the bindings that read that key: one property on
  one instance, not the whole component.
- Code changes **behaviour and layout** (Text, Visible, Size, Interactable, tags).
- Rules change **looks** (colours, fonts, radius, stroke, padding, heights).

## Components

A component is a spec, a table built once per kind, passed to `Component.mount`
with each mount's props:

- **State** lives at `ui.<id>`, starting from `defaults` and the props.
- **`render(h)` runs once**, inside the component's scope. It builds the
  instances with `Lucy.new` and binds them to `h:ref(key)`, other refs and
  getters. Everything it creates belongs to the component and is removed with it.
- **Derived values** are `computed`s, or plain functions when the work is trivial.
- **Shared behaviour** comes from composables: `useDensity`, `useMetric`,
  `useResponsive`, `useBackHandler`, `useFocusScope`, `useUiSound`.
- **What the player did** (activate, toggle, open, close) is reported with
  `h:emit`, so games can play their own sounds through `useUiSound`. Lucy plays
  no audio.
- **Watchers are for side effects only**: tweens, callbacks into game code, focus
  scopes, sounds. A watcher never sets a property, tag or attribute that a
  binding could own.

Most of the cost is at mount, where each bound key gets a binding. After that, a
write runs only the bindings that read it and creates no garbage. See
[Components](./components/index.md#writing-a-component).

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

Every token, option and method is in the [theming reference](reference/theming.md);
[Add a theme](guide/themes.md) walks through using them.

## Scenes and layers

| Layer | DisplayOrder | Shown | Examples |
|---|---|---|---|
| screen | 10 | exactly one (`scenes.current`) | Title, Lobby, Game |
| overlay | 100+ | any, independent (`scenes.visible`) | HUD, chat |
| modal | 200+ | stacked (`scenes.stack`) | Pause, Settings |
| portal: modal | 900 | dialogs and anything else floating, newest on top | Dialog, Dialog.alert |
| portal: toast | 1000 | toasts | app.toast |

[Build screens with scenes](guide/scenes.md) shows how to register and move between them.

## Scaling

You lay out UI in pixels as if the screen were 1280 by 720. Every ScreenGui an
App makes has a UIScale that fits that layout to the real screen, so a layout
keeps its proportions from a phone to a TV and you never do the maths yourself.

Each kind of device scales against its own base size, and only so far:

| Device | Base size | Smallest scale | Largest scale |
|---|---|---|---|
| Phone | 640 x 360 | 0.85 | 1.25 |
| Tablet | 1024 x 640 | 0.85 | 1.5 |
| Desktop | 1280 x 720 | 0.75 | 2 |
| Console | 1280 x 720 | 1 | 2 |

So a 16 pixel gap is 16 layout pixels: about 14 to 20 real pixels on a phone,
and never less than 16 on a TV. Offsets, sizes and `UISizeConstraint` limits
all scale this way. A phone uses a smaller base so text stays readable there.

The scale is measured from each ScreenGui's own size, so a scene with safe area
insets scales to fit the safe area.

`Lucy.App.new({ adaptive = false })` turns scaling off. A table, such as
`{ max = 1.5 }`, changes the numbers for every device. Text sizes and control
heights also grow with the [density](reference/theming.md) (touch and TV).

## Input and focus

`input.mode` follows the last input. `input.device` is derived from capabilities
(`GuiService:IsTenFootInterface()` → console; touch only → mobile or tablet by short side;
otherwise desktop) and drives density and the adaptive profile.

Focus scopes stack: screens and modal scenes push one on enter, dialogs push one
while open. Keyboard Tab/arrows, gamepad selection and `defaultFocus` all work
inside the top scope. The [back keys](#back-keys) call `app.input:back()`. LB / RB call
`app.input:shoulder(-1 / 1)`: from the focused object up, the first component with
a `shoulder(step)` method that returns true handles them, so only the tabs around
the focus switch. Arrow keys, the D-pad and the left stick first call
`app.input:nudge(dx, dy, count)` the same way: a component with a `nudge` method
that returns true takes them (a Slider changes its value), repeating faster while
held, and hears `release()` when let go. Otherwise arrows move focus. Focus that
Lucy moves (Tab, arrows) scrolls into view.

Enter calls `app.input:activate()`. A focused component with `click` or `toggle`
gets that call. A focused part with an `[Lucy.on "Activated"]` handler (a
Select row, a radio option, a sortable header, your own buttons built with
`Lucy.new`) runs that handler, the same thing a click does. Otherwise the first
component from the focused object up with a `press(object)` method that returns
true takes it.

Roblox's own selection image is replaced with a blank frame; Lucy draws its own
ring with the `ui-focus-visible` tag only while navigating with keys or a pad.

### Back keys

B on a gamepad and Backspace on a keyboard go back. Backspace is left alone
while the player is typing in a TextBox.

Escape is not a back key. Roblox opens its own menu on every Escape, and a game
cannot stop or undo that, so going back on Escape would also open the menu on
top. [Known issues](known-issues.md#escape-always-opens-robloxs-menu) has the
details. Choose other keys with `backKeys`:

```luau
local app = Lucy.App.new({
    backKeys = { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace, Enum.KeyCode.Q },
})
```

Adding `Enum.KeyCode.Escape` works, but Roblox's menu still opens every time.

Opening Roblox's menu clears the focus, and closing it does not bring it back,
so Lucy puts focus back where it was when the menu closes.

Hotkeys go through `app.actions`: named actions in sets, built as Roblox
InputContexts, that a game switches off together (the built in `movement` set
stops the character). `app:modalOpen()` says whether a modal overlay is open; a
game decides what to switch off while one is. See
[Hotkeys and modal input](./guide/actions.md).

## Folder layout

```
src/
  init.luau            package entry (Wally)
  Core/                framework; always installed
  Composables/         Lucy.use*: behaviour shared between components
  Components/          one file per component + its spec
  Testing/Harness.luau shared test helpers
tests/Runner.luau      runs every spec, returns a summary
tests/Stories.spec     mounts every story in each theme and device
examples/stories/      a story per component, plus reactivity and scene stories
examples/Showcase      the story browser (Play)
scripts/               add.luau (copy-in CLI), gen-palette.luau, run-tests.server.luau
registry.json          a description of each component for the copy-in CLI
docs/                  the pages this site renders
apps/site/             the website (Vue, prerendered), deployed by .github/workflows/pages.yml
libs/gruff/            the docs engine the site uses (to become its own package)
libs/icons/            lucy-icons, the icon build (published to npm)
```

Only the Luau package ships: the Wally package is checked in CI to contain
nothing but `src/` (without specs and test helpers), `default.project.json`,
`wally.toml`, `README.md` and `LICENSE`.
