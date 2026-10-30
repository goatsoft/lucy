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
function. The component follows it and nothing else re-renders.

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

- **Two-way for writable sources.** A ref, or a computed made with `{ get, set }`,
  is written back when the key changes: the player flips the Switch and `music`
  becomes `false`. `checked`, `value` and `open` are the usual ones to bind this way.
- **One-way for getters.** A plain getter or read-only computed only flows in. If
  the app or the player changes that key, the next change of the source wins.
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
Lucy.Responsive.watch(app, { touch = true, default = false }, function(isTouch) ... end)
```

Keys: device (`mobile tablet desktop console`), input mode (`touch gamepad
keyboard mouse`), breakpoint (`compact regular wide`), orientation (`portrait
landscape`), `default`. First match in that order wins.

## Roadmap (next components)

Tabs, Select, Slider, Tooltip, Dropdown Menu, Scroll Area, Avatar, Alert,
Toggle Group, Sheet (drawer), `toast.promise`, hover-pause for toasts.
