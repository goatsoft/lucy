---
title: Share logic with composables
description: Use Lucy's built in composables and write your own, such as a cooldown for an ability button.
order: 4
---

# Share logic with composables

A composable is a plain function, named `useX`, that creates refs, computeds and
effects and returns them. Call it in a component's render and everything it
creates belongs to that component: it stops when the component is destroyed.

Use one when the same behaviour shows up in more than one component, or when a
render gets long and part of it is about one thing.

## The built in ones

| Composable | Returns |
|---|---|
| `Lucy.useDensity(app)` | `"default"`, `"touch"` or `"tv"`, following the device |
| `Lucy.useMetric(app, token)` | a control size in pixels (`"ControlMd"`), following density |
| `Lucy.useResponsive(app, value)` | a getter for a responsive value such as `{ touch = 16, default = 8 }` |
| `Lucy.useBackHandler(app, active, handler)` | nothing; Escape or ButtonB calls `handler` while `active` is true |
| `Lucy.useFocusScope(app, active, options)` | nothing; keeps keyboard and gamepad focus inside `options.root` while `active` is true |

```lua
render = function(h)
	local height = Lucy.useMetric(h.app, "ControlMd")
	local gap = Lucy.useResponsive(h.app, { touch = 16, default = 8 })

	return Lucy.new "Frame" {
		Size = function()
			return UDim2.new(1, 0, 0, height())
		end,
		Lucy.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = function()
				return UDim.new(0, gap())
			end,
		},
	}
end,
```

`Lucy.Component.list` is for a layout that never changes: it sets its
properties once. A layout with a bound property is made with `Lucy.new`.

`active` can be a ref, a computed or a getter, so a dialog passes its `open` key
and the back handler comes and goes with it:

```lua
local open = h:ref("open")
Lucy.useBackHandler(h.app, open, function()
	open(false)
	return true -- handled; stop here
end)
```

## Write your own: a cooldown

An ability button shows its name when ready, counts down after it is used, and
cannot be pressed until the count reaches zero. The timing is the part worth
sharing, so it goes in a composable:

```lua
local function useCooldown(seconds: number)
	local remaining = Lucy.ref(0)
	local thread: thread? = nil

	local function start()
		if thread then
			task.cancel(thread)
		end
		local endsAt = os.clock() + seconds
		thread = task.spawn(function()
			while os.clock() < endsAt do
				remaining(endsAt - os.clock())
				task.wait(0.1)
			end
			remaining(0)
			thread = nil
		end)
	end

	-- Runs when the owner (the component) is destroyed.
	Lucy.onCleanup(function()
		if thread then
			task.cancel(thread)
		end
	end)

	local ready = Lucy.computed(function()
		return remaining() <= 0
	end)

	return { remaining = remaining, ready = ready, start = start }
end
```

Use it in render like any other value:

```lua
render = function(h)
	local dash = useCooldown(3)

	return Lucy.new "Frame" {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Lucy.Button.new({
			text = function()
				return if dash.ready() then "Dash" else string.format("%.1f s", dash.remaining())
			end,
			disabled = function()
				return not dash.ready()
			end,
			onClick = dash.start,
		}),
	}
end,
```

While the cooldown runs, the button's text updates ten times a second and
nothing else in the component runs. If the component is destroyed mid
cooldown, `onCleanup` cancels the thread.

## The rules

- **Call it where there is an owner**: a component's render, an effect, or
  `scope:run` of a `Lucy.effectScope()`. What it creates stops with that
  owner. The built in composables raise an error if there is none.
- **Take refs or getters, return refs, computeds or functions.** Taking a ref
  (rather than a plain value) lets the caller pass a component key, an
  `app.state:ref` or a computed and have the composable follow it.
  `Lucy.toValue(x)` reads any of them, and a plain value too.
- **Clean up with `Lucy.onCleanup`**: connections, threads, anything the
  owner stopping would not otherwise end. Effects and computeds made inside the
  composable stop on their own.
- **Keep watchers for side effects.** If the composable's result is a value,
  return a computed. Use `Lucy.watch` only to do something, such as play a
  sound when a value crosses a line.

## Next

- [Reactivity](../reactivity.md#composables): composables in the reference,
  next to effects and lifetime.
- [Build a component](./components.md)
