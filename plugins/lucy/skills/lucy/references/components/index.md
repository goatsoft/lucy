<!-- Made by scripts/skills.ts from docs/components/index.md. Edit the doc, not this file. -->
# Components

Each component has its own page with its props, usage and examples:

| Component | What it is |
|---|---|
| [Accordion](accordion.md) | Sections the player opens and closes, one or several at a time |
| [Alert](alert.md) | A box that calls attention to a message |
| [Avatar](avatar.md) | A player's headshot, or a monogram for a bot |
| [Badge](badge.md) | A small label for a status or count |
| [Button](button.md) | A button, in six variants and four sizes |
| [Checkbox](checkbox.md) | A box that can be checked, with an optional label |
| [Collapsible](collapsible.md) | A header that shows or hides what is under it |
| [DataGrid](data-grid.md) | A table the player can sort by pressing its headers |
| [Dialog](dialog.md) | A modal window, and alert dialogs that ask for a yes or no |
| [Grid](grid.md) | Rows of equal cells, such as shop items or emotes |
| [Icon](icon.md) | A small picture in the theme's colours, by name or asset id |
| [Image](image.md) | A picture from an asset id or a thumbnail |
| [Input](input.md) | A text field on one line |
| [Item](item.md) | A row in a list, with media, a title, a description and actions |
| [Kbd](kbd.md) | The key to press, for the player's keyboard or controller |
| [Number Field](number-field.md) | A number with minus and plus buttons, typed or stepped |
| [Panel](panel.md) | A card with a header, content and footer |
| [Pressable](pressable.md) | A surface the player can click that holds anything |
| [Progress](progress.md) | A bar that fills from 0 to a maximum |
| [Radio Group](radio-group.md) | A list of options where the player picks exactly one |
| [Scroll Area](scroll-area.md) | A region that scrolls when its content does not fit |
| [Select](select.md) | A button that opens a list of options to pick one from |
| [Separator](separator.md) | A thin line between items |
| [Sheet](sheet.md) | A panel from the side of the screen, a drawer from the bottom on touch |
| [Skeleton](skeleton.md) | A pulsing placeholder while content loads |
| [Slider](slider.md) | Picks a number in a range by dragging or with the arrows |
| [Spinner](spinner.md) | A turning ring while something loads |
| [Stack](stack.md) | A row or column that lays out its children |
| [Switch](switch.md) | An on and off switch, with an optional label |
| [Table](table.md) | Rows and columns for leaderboards, friends lists and inventories |
| [Tabs](tabs.md) | A tab bar with one panel per tab |
| [Text](text.md) | Headings, body copy and labels |
| [Toaster](toaster.md) | Toast notifications through `app.toast` |
| [Toggle](toggle.md) | A button that stays pressed until it is clicked again |
| [Toggle Group](toggle-group.md) | A row of toggles where the player picks one or several |

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

## Reactive props

Every state key listed on a component's page also accepts a ref, a computed or a
getter function. The component follows it and nothing else runs again.

```luau
local coins = Lucy.ref(0)
local isBusy = Lucy.ref(false)
local music = Lucy.ref(true)

Lucy.Button.new({
    text = function() return `Buy ({coins()})` end,
    disabled = isBusy,
})
Lucy.Switch.new({ label = "Music", checked = music })
```

- **Writable sources bind both ways.** A ref, or a computed made with `{ get, set }`,
  is written back when the key changes: the player flips the Switch and `music`
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
landscape`), `default`. First match in that order wins.

## Writing a component

A component is a spec, a table built once, passed to `Lucy.Component.mount` with
each mount's props. Its `render` runs once per mount and describes the instances;
bindings keep them in step with state from then on.

```luau
local TweenService = game:GetService("TweenService")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local Stat = {}

local rules: { Lucy.Rule } = {
    { selector = ".ui-stat", priority = 0, properties = { BackgroundColor3 = "$Card", BorderSizePixel = 0 } },
    { selector = ".ui-stat.ui-low", priority = 10, properties = { BackgroundColor3 = "$Destructive" } },
    {
        selector = ".ui-stat-text",
        priority = 0,
        properties = { BackgroundTransparency = 1, TextColor3 = "$CardForeground", FontFace = "$FontSansSemibold" },
    },
}
Stat.rules = rules

-- Built once and shared by every Stat.
local spec: Lucy.Spec = {
    kind = "stat",
    defaults = { label = "", value = 0, low = 10, visible = true }, -- the keys in ui.<id>
    rules = Stat.rules,
    render = function(h)
        local label, value, low = h:ref("label"), h:ref("value"), h:ref("low")
        -- Read by two bindings and a watcher, so a computed; trivial ones can be plain functions.
        local isLow = Lucy.computed(function()
            return value() <= low()
        end)
        local height = Lucy.useMetric(h.app, "ControlMd") -- follows density

        local text = Lucy.new "TextLabel" {
            Size = function() return UDim2.new(1, 0, 0, height()) end,
            Text = function() return `{label()}: {value()}` end,
            Tags = { "ui-stat-text" },
        }

        -- A side effect, so a watcher: pulse when the stat turns low.
        local pulse = TweenService:Create(text, TweenInfo.new(0.2, Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out, 0, true), { TextTransparency = 0.5 })
        Lucy.watch(isLow, function(nowLow)
            if nowLow then pulse:Play() end
        end)

        return Lucy.new "Frame" {
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = h:ref("visible"),
            Tags = { "ui-stat", ["ui-low"] = isLow },
            text,
        }
    end,
}

function Stat.new(props: Lucy.Props?): Lucy.Handle
    return Lucy.Component.mount(spec, props)
end

return Stat
```

- **`h:ref(key)`** is a writable ref onto one state key. Reading it in a binding or
  computed subscribes to that key only; writing it writes the store. `h:get(key)` reads without tracking,
  `h:set(key, value)` writes one key and `h:set(patch)` merges several.
- **Everything render creates belongs to the component**: bindings, computeds,
  watchers, composables and the elements themselves. Destroying the handle stops
  all of it.
- **Validate in render.** Check props there (an unknown variant, say) so a bad
  value fails `new` itself. A binding that sees a bad value later reports it
  like any effect error.
- **Variants are tags.** Bind them with a getter in `Tags`:
  `function() return "ui-stat-tone-" .. tone() end`. Looks stay in rules.
- **Static helpers can stay plain.** Layout objects with no bindings, such as a
  `UIListLayout`, can be `Lucy.Component.list(...)` or `Lucy.Component.create(...)`.
- **Build the spec once.** A spec made at the top of the module costs nothing per
  mount. Read each mount's own props (callbacks and the like) from `h.props`.
- **Methods go on the handle** after `mount` returns: `function handle.toggle(h) ... end`.
- **Clickable components** call `Lucy.Component.clickable(handle)` after `mount`:
  it adds `handle.Activated`, `handle:click()` and the `onClick` prop, the same as
  Button and Pressable.
- **Report what the player did** with `h:emit(event, value)` (`activate`, `toggle`,
  `open`, `close`), so games can play sounds for it through
  [useUiSound](../reference/composables.md#useuisound).

### Watchers are a last resort

A watcher that sets a property is a binding written the long way: it runs more
often, and the property now has two owners. Bind the property instead.

```luau
-- No: a watcher setting what a binding could own.
Lucy.watch(h:ref("disabled"), function(off) button.Interactable = not off end)

-- Yes: a binding.
Interactable = function() return not disabled() end,
```

Use `Lucy.watch` and `Lucy.watchEffect` for side effects only: tweens, callbacks
into game code (`onCheckedChange`), focus scopes and back handlers (through their
composables), sounds, timers.

### Where the cost goes

Each bound key costs a little at mount: it gets a binding, and the store sets
up tracking for it the first time it is read. That is paid once. After that, a
write runs only the bindings that read the key and creates no garbage: changing
a Button's text sets its `Text` again and nothing else. See
[Benchmarks](https://lucy.goatsoft.io/docs/benchmarks/).

## Roadmap

After 0.1.0: Tooltip, Carousel, Field, Empty, Dropdown Menu, `toast.promise`, pausing
toasts on hover.
