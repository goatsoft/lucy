<!-- Made by scripts/skills.ts from docs/reference/api.md. Edit the doc, not this file. -->
# Everything on Lucy

`require(Lucy)` returns one table. This page lists everything on it, so you can
check a name exists before you use it, and find the page that explains it.

## Reactivity

| Name | What it is | More |
|---|---|---|
| `Lucy.ref`, `computed`, `reactive` | State that code can follow | [Reactivity](../reactivity.md#state) |
| `Lucy.watch`, `watchEffect` | Run code when state changes | [Effects](../reactivity.md#effects) |
| `Lucy.effectScope`, `onCleanup` | Group effects and stop them together | [Lifetime](../reactivity.md#lifetime) |
| `Lucy.batch`, `untrack`, `peek`, `toValue`, `toRaw` | Write several values at once; read without following | [Effects](../reactivity.md#effects) |
| `Lucy.isRef`, `isWritable`, `isReactive` | Tell what kind of value you have | [Effects](../reactivity.md#effects) |
| `Lucy.insert`, `remove` | Add to and remove from a list in a `reactive` table, so readers update | [reactive](../reactivity.md#reactive) |
| `Lucy.trigger` | Tell readers of a ref it changed, after editing a table inside it in place | [Effects](../reactivity.md#effects) |

## Building UI

| Name | What it is | More |
|---|---|---|
| `Lucy.new` | Make an instance with bound properties: `Lucy.new "Frame" { ... }` | [Declarative UI](../reactivity.md#declarative-ui) |
| `Lucy.hydrate` | Bind an instance built in Studio | [UI built in Studio](../reactivity.md#ui-built-in-studio) |
| `Lucy.on`, `changed`, `out`, `model`, `instance` | Keys for events, property changes and two way bindings | [Declarative UI](../reactivity.md#declarative-ui) |
| `Lucy.show`, `each` | Show something while a condition holds; one item per list entry | [Conditionals and lists](../reactivity.md#conditionals-and-lists) |
| `Lucy.Component` | Build your own component | [Build a component](../guide/components.md) |

## Composables

`Lucy.useDensity`, `useMetric`, `useResponsive`, `useBackHandler`,
`useFocusScope`, `useFocusZone`, `useHoldArrows`, `useSize`, `useUiSound`, `useTable`, `useSort`, `useWhile`, `useCountdown`,
`useDrag`, `useReveal`, `useCount` and `useRequest`. See
the [composables reference](composables/index.md).

## Animation

| Name | What it is | More |
|---|---|---|
| `Lucy.spring`, `tween` | Values that move smoothly to a target, and follow reduced motion | [Animation](../reactivity.md#animation) |

## Images

| Name | What it is | More |
|---|---|---|
| `Lucy.preload`, `Preload` | Fetches pictures before they are shown, in one shared queue | [Preloading](../components/image.md#preloading) |

## The App and its parts

| Name | What it is | More |
|---|---|---|
| `Lucy.App` | Make the App: `Lucy.App.new(options)` | [The app](app.md) |
| `Lucy.AppState` | The store's class; use `app.state` | [The store](store.md) |
| `Lucy.Theme` | The theme's class; use `app.theme` | [Theming](theming.md) |
| `Lucy.SceneManager` | The scenes' class; use `app.scenes` | [Build screens with scenes](../guide/scenes.md) |
| `Lucy.InputManager` | Input's class; use `app.input` | [Input and focus](../architecture.md#input-and-focus) |

## On the server

| Name | What it is | More |
|---|---|---|
| `Lucy.Server` | The server's store, sent to each player's App at `server.*`, and requests from them: `Lucy.Server.new(options)` | [The server](server.md) |
| `Lucy.DataQueue` | DataStore requests paced to the engine's limits, with cached reads and a flush on close: `Lucy.DataQueue.new(options)` | [The data queue](data-queue.md) |
| `Lucy.Boards` | Leaderboards on the server: all time, this week and today, each player's rank, names, the request and published rows: `Lucy.Boards.new(options)` | [Boards](boards.md) |

## Themes and colour

| Name | What it is | More |
|---|---|---|
| `Lucy.Tokens` | The design tokens and the theme builders (`themesFor`, `onColor`) | [Theming](theming.md#lucytokens) |
| `Lucy.Palette` | Every palette colour as OKLCH values | [Theming](theming.md#lucytokens) |
| `Lucy.Oklab` | Colour maths: convert, mix, and check contrast | [Theming](theming.md#lucytokens) |
| `Lucy.Preferences` | The player's accessibility settings: reduced motion, text size, background transparency | [Accessibility](accessibility.md#lucypreferences) |

## Devices and layout

| Name | What it is | More |
|---|---|---|
| `Lucy.Responsive` | Pick a value by device, input, breakpoint or orientation: `Responsive.pick(app, { mobile = 2, default = 5 })` | [Components](../components/index.md) |
| `Lucy.Adaptive` | Scales each ScreenGui for the device | [Scaling](../architecture.md#scaling) |
| `Lucy.Scroll` | `Scroll.reveal(object, margin?, only?)` scrolls every ScrollingFrame above `object` (or only `only`) so it shows | [Utils](utils.md#lucyscroll) |

## Components

`Lucy.Accordion`, `Alert`, `Arrow`, `Attribution`, `Avatar`, `Badge`, `Button`, `Checkbox`,
`Collapsible`, `DataGrid`, `Dialog`, `Effect`, `Gradient`, `Grid`, `Icon`, `Image`, `InlineConfirm`,
`Input`, `Item`, `Kbd`, `Leaderboard`, `Marquee`, `Menu`, `NumberField`, `Panel`, `Pressable`, `Progress`,
`RadioGroup`, `ScrollArea`, `Select`, `Separator`, `Sheet`, `Skeleton`,
`Slider`, `Slot`, `SortButton`, `Spinner`, `Stack`, `Switch`, `Table`, `Tabs`, `Text`, `Toaster`,
`Toggle`, `ToggleGroup`, `Tour` and `Waveform`. Each has a page under [Components](../components/index.md).

## Tools

| Name | What it is | More |
|---|---|---|
| `Lucy.Preview` | Show stories in Studio | [Stories](../stories.md) |
| `Lucy.Devtools` | Look at and drive a running UI in Studio | [Devtools](devtools.md) |

## Utils and helpers

Lucy uses these itself, and you can too.

| Name | What it is | More |
|---|---|---|
| `Lucy.Format` | Turns values into text, such as `Format.number(4200)`, which is `"4,200"` | [Utils](utils.md#lucyformat) |
| `Lucy.Scroll` | Scrolls ScrollingFrames to reveal an object, calculates offsets and scales | [Utils](utils.md#lucyscroll) |
| `Lucy.Signal` | A small event for plain Luau objects: `Signal.new()`, `:Connect(fn)`, `:Fire(...)` | [Utils](utils.md#lucysignal) |
| `Lucy.Maid` | Collects things to clean up and cleans them in one call | [Utils](utils.md#lucymaid) |

`Lucy.Reactive`, `Lucy.Element` and `Lucy.Animate` are the modules behind the
shortcuts above (`Lucy.ref` is `Lucy.Reactive.ref`). Use the shortcuts.
