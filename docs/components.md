---
title: Components
description: Props, state keys and responsive values for every Lucy component.
order: 1
---

# Components

Every component is `X.new(props)` and returns a handle:

- `handle.Instance`: the root Instance
- `handle:get(key?)`, `handle:set(patch)`: read and write its state at `ui.<id>`
- `handle:destroy()`
- common props: `app`, `id`, `Parent`, `name`, `layoutOrder`, `persist`
  (keep state after destroy)

Any state key can be driven from the app: `app.state:set("ui.<id>.<key>", value)`.

## Reactive props

Every state key in the table below also accepts a ref, a computed or a getter
function. The component follows it and nothing else runs again.

```lua
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

| Component | State keys | Notes |
|---|---|---|
| Button | text, variant, size, disabled, visible | variants: default, destructive, outline, secondary, ghost, link. sizes: sm, md, lg, icon. `onClick`, `Activated`, `:click()` |
| Badge | text, variant, visible | default, secondary, destructive, outline |
| Text | text, variant, align, visible | h1 to h4, p, lead, large, small, muted, label. `autoWidth`, `richText` |
| Panel | title, description, visible | `children`, `footer`, `size`, `maxWidth`, `aspectRatio`; `.header .content .footer` |
| Dialog | open, title, description | `actions`, `dismissible`, `closeOnOverlay`, `showClose`, `onOpenChange`, `:open() :close() :toggle()`, `Dialog.alert{}` |
| Toaster | (list in `toasts`) | `app.toast(msg, opts)`, `.success .error .warning .info`, `.dismiss(id?)`, update by `id`, `action` |
| Input | value, placeholder, disabled, visible | `onChange`, `onSubmit`, `width`, `:focus()` |
| Checkbox | checked, label, disabled, visible | `onCheckedChange`, `:toggle()`, row is the hit area |
| Switch | checked, label, disabled, visible | `onCheckedChange`, `:toggle()` |
| Progress | value, max, visible | clamped |
| Skeleton | visible | `size`, `circle`; pulses while visible |
| Separator | orientation, visible | horizontal, vertical |
| Stack | visible | `direction`, `gap`, `align`, `justify`, `padding`, `wrap`, `size`, `children`; all layout props accept responsive values |

## Responsive values

```lua
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

A component is a table passed to `Lucy.Component.mount`. Its `render` runs once and
describes the instances; bindings keep them in step with state from then on.

```lua
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

function Stat.new(props: Lucy.Props?): Lucy.Handle
    return Lucy.Component.mount({
        kind = "stat",
        props = props,
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
    })
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
- **Methods go on the handle** after `mount` returns: `function handle.toggle(h) ... end`.

### Watchers are a last resort

A watcher that sets a property is a binding written the long way: it runs more
often, and the property now has two owners. Bind the property instead.

```lua
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
[Benchmarks](./benchmarks.md).

## Roadmap (next components)

Tabs, Select, Slider, Tooltip, Dropdown Menu, Scroll Area, Avatar, Alert,
Toggle Group, Sheet (drawer), `toast.promise`, pausing toasts on hover.
