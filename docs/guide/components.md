---
title: Build a component
description: Write a Stepper component step by step, with state keys, h:ref, bindings, methods and a value bound to app state.
order: 8
---

# Build a component

This guide builds a Stepper: a label, a number and two buttons that move the
number between a minimum and a maximum. It covers everything most components
need: state keys, `h:ref`, bindings, child components, methods and binding a
value to app state.

```
Volume   [ - ]  4  [ + ]
```

## The state keys

A component keeps its state in the app's store, at `ui.<id>`. The keys it has
are its `defaults`. Props with the same names set the starting values.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local Stepper = {}

-- Built once and shared by every Stepper.
local spec: Lucy.Spec = {
    kind = "stepper",
    defaults = { label = "", value = 0, min = 0, max = 10, step = 1, visible = true },
    render = function(h)
        -- next section
    end,
}

function Stepper.new(props: Lucy.Props?): Lucy.Handle
    return Lucy.Component.mount(spec, props)
end

return Stepper
```

`Stepper.new({ id = "volume", label = "Volume", max = 10 })` stores
`{ label = "Volume", value = 0, min = 0, max = 10, step = 1, visible = true }` at
`ui.volume`. Without an `id`, Lucy makes one up (`stepper-1`, `stepper-2`...).

Because the state lives in the store, game code can drive a component without a
reference to it: `app.state:set("ui.volume.value", 5)` moves the number.

The spec is made once, when the module loads, and every Stepper shares it. Each
`Stepper.new` passes its own props to `mount`, and `render` can read them from
`h.props` (a callback, say).

## Render runs once

`render` runs once, when the component is created. It returns the root
instance and sets up bindings that keep it in step with state from then on.

`h:ref(key)` is a ref onto one state key. Call it with no argument to read the
key, with one argument to write it. Use it anywhere a property takes a value:

```luau
render = function(h)
    local value = h:ref("value")

    return Lucy.new "Frame" {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        Visible = h:ref("visible"),
        Lucy.Component.list({
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
        }),
        Lucy.Text.new({ text = h:ref("label"), variant = "label", autoWidth = true }),
        Lucy.Text.new({
            text = function()
                return tostring(value())
            end,
            autoWidth = true,
        }),
    }
end,
```

There are three kinds of value here:

- **A plain value** (`BackgroundTransparency = 1`) is set once.
- **A ref** (`Visible = h:ref("visible")`) is followed: when the key changes,
  `Visible` is set again.
- **A function** (the second `text`) is a getter. Lucy runs it, notes which refs
  it read, and runs it again when one of them changes. Here, writing `value`
  updates that label and nothing else.

Child components such as `Lucy.Text` go straight into the children list, like
instances. `render` must return an instance, though, not another component:
wrap children in a Frame as above. Everything render creates belongs to the
component: bindings, children, computeds and watchers all stop when it is
destroyed.

## Respond to clicks

Add the two buttons. Writing a ref writes the store, so every binding that reads
`value` follows:

```luau
local value, min, max, step = h:ref("value"), h:ref("min"), h:ref("max"), h:ref("step")

local function decrease()
    value(math.max(min(), value() - step()))
end

local function increase()
    value(math.min(max(), value() + step()))
end
```

```luau
Lucy.Button.new({ text = "-", size = "icon", variant = "outline", onClick = decrease }),
-- the number label
Lucy.Button.new({ text = "+", size = "icon", variant = "outline", onClick = increase }),
```

The children appear in the order you list them.

## Derive values with computed

The minus button should be disabled at the minimum, and the plus button at the
maximum. A value worked out from other values is a `Lucy.computed`. It runs
again only when something it read changes, and tells its readers only when its
result changes:

```luau
local atMin = Lucy.computed(function()
    return value() <= min()
end)
local atMax = Lucy.computed(function()
    return value() >= max()
end)
```

Pass them to the buttons' `disabled` prop. A component prop takes a value, a
ref, a computed or a getter, the same as a property:

```luau
Lucy.Button.new({ text = "-", size = "icon", variant = "outline", disabled = atMin, onClick = decrease }),
```

A one line getter works too (`disabled = function() return value() <= min() end`).
A computed is worth it when more than one binding reads the same result.

## Add methods

Methods go on the handle after `mount` returns. `h:get(key)` reads a key
without following it, and `h:set(key, value)` writes one:

```luau
local handle = Lucy.Component.mount(spec, props)

function handle.reset(h)
    h:set("value", h:get("min"))
end

return handle
```

`h:set({ value = 0, max = 20 })` writes several keys at once.

## The whole component

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local Stepper = {}

-- Built once and shared by every Stepper.
local spec: Lucy.Spec = {
    kind = "stepper",
    defaults = { label = "", value = 0, min = 0, max = 10, step = 1, visible = true },
    render = function(h)
        local value, min, max, step = h:ref("value"), h:ref("min"), h:ref("max"), h:ref("step")
        local atMin = Lucy.computed(function()
            return value() <= min()
        end)
        local atMax = Lucy.computed(function()
            return value() >= max()
        end)

        return Lucy.new "Frame" {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.XY,
            Visible = h:ref("visible"),
            Lucy.Component.list({
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 8),
            }),
            Lucy.Text.new({ text = h:ref("label"), variant = "label", autoWidth = true }),
            Lucy.Button.new({
                text = "-",
                size = "icon",
                variant = "outline",
                disabled = atMin,
                onClick = function()
                    value(math.max(min(), value() - step()))
                end,
            }),
            Lucy.Text.new({
                text = function()
                    return tostring(value())
                end,
                autoWidth = true,
            }),
            Lucy.Button.new({
                text = "+",
                size = "icon",
                variant = "outline",
                disabled = atMax,
                onClick = function()
                    value(math.min(max(), value() + step()))
                end,
            }),
        }
    end,
}

function Stepper.new(props: Lucy.Props?): Lucy.Handle
    local handle = Lucy.Component.mount(spec, props)

    function handle.reset(h)
        h:set("value", h:get("min"))
    end

    return handle
end

return Stepper
```

## Use it

```luau
local volume = Stepper.new({ id = "volume", label = "Volume", max = 10, Parent = scene.gui })

volume:set("value", 4)              -- from code that holds the handle
app.state:set("ui.volume.value", 4) -- from anywhere else
volume:reset()
volume:destroy()                    -- stops its bindings and removes ui.volume
```

## Bind it to your own state

Give a prop a ref and the key follows it both ways. Here the Stepper's `value`
is the player's saved setting, so there is no copy to keep in sync:

```luau
local app = Lucy.App.new({ state = { settings = { volume = 6 } } })

Stepper.new({
    label = "Volume",
    value = app.state:ref("settings.volume"),
    Parent = scene.gui,
})
```

Clicking plus writes `settings.volume`, and setting `settings.volume` from game
code moves the number. Any writable ref works the same way: `Lucy.ref`, a
computed with `get` and `set`, or `app.state:ref`. A getter that only reads, such
as `max = function() return level() * 5 end`, is followed one way: the key takes
its value whenever it changes.

## Styling

The Stepper sets `BackgroundTransparency` directly because a transparent frame
is not a look. For colours, fonts and sizes, add tags and rules so themes and
density apply. See [Writing a component](../components/index.md#writing-a-component)
for rules, variants as tags, and why watchers are kept for side effects only.

## Next

- [Work with app state](./app-state.md): paths, refs onto them, lists and
  subscribers.
- [Share logic with composables](./composables.md): pull reusable behaviour out
  of render.
