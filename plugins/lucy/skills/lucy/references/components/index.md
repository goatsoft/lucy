<!-- Made by scripts/skills.ts from docs/components/index.md. Edit the doc, not this file. -->
# Components

47 components, grouped by what they do.

## Actions and choices

| Component | What it is |
|---|---|
| [Button](button.md) | A button, in six variants and four sizes |
| [Checkbox](checkbox.md) | A box that can be checked, with an optional label |
| [Inline Confirm](inline-confirm.md) | Asks "Are you sure?" in place, with YES and NO |
| [Menu](menu.md) | Actions that open as a list, a ring or a fan and close once one is picked |
| [Pressable](pressable.md) | A surface the player can click that holds anything |
| [Radio Group](radio-group.md) | A list of options where the player picks exactly one |
| [Select](select.md) | A button that opens a list of options to pick one from |
| [Switch](switch.md) | An on and off switch, with an optional label |
| [Toggle](toggle.md) | A button that stays pressed until it is clicked again |
| [Toggle Group](toggle-group.md) | A row of toggles where the player picks one or several |

## Forms and inputs

| Component | What it is |
|---|---|
| [Input](input.md) | A text field, on one line or several |
| [Number Field](number-field.md) | A number with minus and plus buttons, typed or stepped |
| [Slider](slider.md) | Picks a number in a range by dragging or with the arrows |

## Layout and surfaces

| Component | What it is |
|---|---|
| [Accordion](accordion.md) | Sections the player opens and closes, one or several at a time |
| [Collapsible](collapsible.md) | A header that shows or hides what is under it |
| [Gradient](gradient.md) | One of the theme's gradients on a frame, a panel or a button |
| [Grid](grid.md) | Rows of equal cells, such as shop items or emotes |
| [Panel](panel.md) | A card with a header, content and footer |
| [Scroll Area](scroll-area.md) | A region that scrolls when its content does not fit |
| [Separator](separator.md) | A thin line between items |
| [Slot](slot.md) | What goes inside a badge, button, tab or option, and how it takes the component's colours |
| [Stack](stack.md) | A row or column that lays out its children |
| [Tabs](tabs.md) | A tab bar with one panel per tab |

## Lists and data

| Component | What it is |
|---|---|
| [DataGrid](data-grid.md) | A table the player can sort by pressing its headers |
| [Item](item.md) | A row in a list, with media, a title, a description and actions |
| [Leaderboard](leaderboard.md) | Ranked players with medals for the top three and the player's own row pinned |
| [SortButton](sort-button.md) | A column heading that sorts a list when pressed |
| [Table](table.md) | Rows and columns for leaderboards, friends lists and inventories |

## Overlays, tours and alerts

| Component | What it is |
|---|---|
| [Alert](alert.md) | A box that calls attention to a message |
| [Arrow](arrow.md) | A big arrow that points at something on screen, grows in and bounces |
| [Dialog](dialog.md) | A modal window, and alert dialogs that ask for a yes or no |
| [Sheet](sheet.md) | A panel from the side of the screen, a drawer from the bottom on touch |
| [Toaster](toaster.md) | Toast notifications through `app.toast` |
| [Tour](tour.md) | A guided walk through your game's own UI, one step at a time |

## Display, motion and media

| Component | What it is |
|---|---|
| [Attribution](attribution.md) | A badge displaying "Built with Lucy" with Lucy's mascot head |
| [Avatar](avatar.md) | A player's headshot, or a monogram for a bot |
| [Badge](badge.md) | A small label for a status or count |
| [Effect](effect.md) | An animated celebration behind a reward or a level up: rays, outline, or your own |
| [Icon](icon.md) | A small picture in the theme's colours, by name or asset id |
| [Image](image.md) | A picture from an asset id or a thumbnail |
| [Kbd](kbd.md) | The key to press, for the player's keyboard or controller |
| [Marquee](marquee.md) | One line of text that scrolls, back and forth or round like a ticker, when it is too long to fit |
| [Progress](progress.md) | A bar that fills from 0 to a maximum |
| [Skeleton](skeleton.md) | A pulsing placeholder while content loads |
| [Spinner](spinner.md) | A turning ring while something loads |
| [Text](text.md) | Headings, body copy and labels |
| [Waveform](waveform.md) | A row of columns from levels: a song's loudness, an equaliser, a meter |

## Using a component

Every component is `X.new(props)` and returns a handle:

- `handle.Instance`: the root Instance
- `handle:get(key?)`, `handle:set(patch)`: read and write its state at `ui.<id>`
- `handle:destroy()`

Every component also takes these props:

| Prop | What it does |
|---|---|
| `id` | Where its state lives: `ui.<id>`. Made up for you if left out |
| `Parent` | The Instance to put it in |
| `app` | The App it belongs to. Defaults to the current App |
| `name` | The root Instance's Name |
| `layoutOrder` | The root Instance's LayoutOrder |
| `persist` | Keep its state in the app after it is destroyed |

Any state key can be changed from the app: `app.state:set("ui.<id>.<key>", value)`.

A prop a component doesn't know is ignored, without an error, so check the
component's page for its name. To place a component, put it in a
[Stack](stack.md) or [Grid](grid.md), or set layout properties on its root
after making it:

```luau
local gear = Lucy.Button.new({ icon = "lucide-extended:settings-filled", size = "icon", Parent = scene.gui })
gear.Instance.AnchorPoint = Vector2.new(1, 0)
gear.Instance.Position = UDim2.new(1, -16, 0, 16)
```

`Position`, `AnchorPoint`, `ZIndex` and `LayoutOrder` are safe to set this way.
Leave `Size` and colours alone on components whose size comes from the theme,
such as Button and Input: a rule sets them and would win.

Where a component takes `children`, each one is an Instance, a component, or a
function called with the frame to fill. A function's return value is not used,
so for a list from state, put `Lucy.each` in a `Lucy.new` frame and pass that
(see [Work with app state](../guide/app-state.md)).

## Reactive props

Every state key listed on a component's page also accepts a ref, a computed or a
getter function. The component follows it and nothing else runs again.

```luau
local coins = Lucy.ref(0)
local isBusy = Lucy.ref(false)
local lights = Lucy.ref(true)

Lucy.Stack.new({
    gap = "Space3",
    children = {
        Lucy.Button.new({
            text = function() return `Buy ({coins()})` end,
            disabled = isBusy,
        }),
        Lucy.Switch.new({ label = "Club lights", checked = lights }),
    },
    Parent = parent,
})
```

- **Writable sources bind both ways.** A ref, or a computed made with `{ get, set }`,
  is written back when the key changes: the player flips the Switch and `lights`
  becomes `false`. `checked`, `value` and `open` are the usual ones to bind this way.
- **Getters only flow in.** A plain getter, or a computed without `set`, is read
  but never written back. If the app or the player changes that key, the next
  change of the source wins.
- **App state still works.** Bound values land in `ui.<id>` like any other, so
  `app.state` subscribers and `handle:get` see them.
- **Lifetime.** A component created inside an effect, a `show` branch, an `each`
  item or a scope is destroyed when that owner stops. Destroying it stops its
  bindings.
- Callback and layout props (`onClick`, `children`, `gap`, ...) stay plain.

## Responsive values

```luau
Lucy.Stack.new({
    direction = { mobile = "vertical", default = "horizontal" },
    gap = { console = "Space6", touch = "Space4", default = "Space2" },
})
local columns = Lucy.Responsive.pick(app, { console = 4, tablet = 3, mobile = 2, default = 5 })

-- In a render, an effect or a scope: a getter that follows the input state.
local gap = Lucy.useResponsive(app, { touch = 16, default = 8 })
Lucy.new "UIListLayout" { Padding = function() return UDim.new(0, gap()) end }
```

Keys: device (`mobile tablet desktop console`), input mode (`touch gamepad
keyboard mouse`), breakpoint (`compact regular wide`), orientation (`portrait
landscape`), height (`short tall`: short is under 500 pixels, a phone held
sideways or a short window), `default`. First match in that order wins.

## Writing a component

A component is a spec table passed to `Lucy.Component.mount` with each mount's
props. `render` runs once to describe the instances, and bindings keep them in
step with state from then on. For the full walkthrough, rules and performance
notes, see [Build a component](../guide/components.md) and
[Benchmarks](https://lucy.goatsoft.io/docs/benchmarks/).

## Roadmap

After 0.1.0: Tooltip, Carousel, Field, Empty, `toast.promise`, pausing toasts
on hover.
