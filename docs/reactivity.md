---
title: Reactivity
description: ref, computed, reactive and watch; Lucy.new for declarative UI; springs and tweens.
order: 0
---

# Reactivity

Lucy's state primitives use Vue's names with Luau call syntax. A ref is a function:
call it to read, call it with a value to write. There is no `.value` and no
unwrapping magic.

```lua
local count = Lucy.ref(0)
count()        -- 0
count(5)       -- write: everything that read count updates
```

Updates are fine-grained. When `count` changes, only the exact properties and
effects that read it run again. Nothing re-renders, and nothing is diffed.

## State

### ref

```lua
local name = Lucy.ref("Lucy")
name("Goat")              -- write
name(nil)                 -- writing nil is fine
Lucy.trigger(list)        -- notify after mutating a ref's table in place
```

Writing the value a ref already holds does nothing.

### computed

A cached, lazy derivation. It runs when first read, and again only when something
it read has changed.

```lua
local double = Lucy.computed(function()
	return count() * 2
end)
```

Make it writable by passing `get` and `set`:

```lua
local fullName = Lucy.computed({
	get = function() return `{first()} {last()}` end,
	set = function(value)
		local a, b = string.match(value, "^(%S+) (%S+)$")
		first(a)
		last(b)
	end,
})
fullName("Goat Soft")
```

A computed that ends up with the same value stops the update there, so
`isAlive = computed(function() return hp() > 0 end)` only notifies when it flips.

### reactive

A deep, reactive view of a table, for state you would rather write as fields.

```lua
local player = Lucy.reactive({ coins = 0, bag = {} })
player.coins += 10                 -- only readers of `coins` update
Lucy.insert(player.bag, "sword")   -- lists: use Lucy.insert / Lucy.remove
for i, item in player.bag do end   -- generalized iteration and # are tracked
```

The `table` library works on raw tables, so `table.insert(player.bag, x)` would
bypass tracking. Use `Lucy.insert` and `Lucy.remove`, or assign `bag[#bag + 1] = x`.
`Lucy.toRaw(proxy)` returns the plain table. Frozen tables are left as they are.

### App state as a ref

```lua
local coins = app.state:ref("player.coins")
coins(coins() + 10)    -- writes through app.state:set
```

It follows writes from anywhere, so the store and your bindings stay in step.

## Effects

```lua
local stop = Lucy.watchEffect(function(onCleanup)
	print("coins", coins())
	onCleanup(function() end)   -- before the next run, and on stop
end)

Lucy.watch(count, function(new, old, onCleanup) end)                 -- lazy
Lucy.watch(count, callback, { immediate = true })                    -- run now too
Lucy.watch({ a, b }, function(values, previous) end)                 -- several sources
Lucy.watch(function() return player.coins end, callback)             -- a getter
Lucy.watch(player, callback)                                         -- deep, any change
```

- `Lucy.batch(fn)` groups writes; dependents run once, afterwards.
- `Lucy.untrack(fn)` and `Lucy.peek(source)` read without subscribing.
- `Lucy.toValue(x)` reads a ref, computed or getter, and passes plain values through.

An effect never re-triggers itself by writing a ref it reads. Effects that keep
triggering each other are stopped after 100 rounds with an error, instead of
freezing the game.

## Lifetime

Everything created inside an effect, an element or a scope belongs to it, and is
cleaned up when its owner re-runs or stops. You rarely need to think about it.

```lua
local scope = Lucy.effectScope()
scope:run(function()
	-- effects, computeds, elements...
	Lucy.onCleanup(function() end)
end)
scope:stop()   -- stops all of it
```

## Declarative UI

`Lucy.new` creates an instance. Any property can be a ref, a computed or a getter.

```lua
local count = Lucy.ref(0)

Lucy.new "TextButton" {
	Size = UDim2.fromOffset(200, 40),
	Text = function() return `Clicked {count()}` end,
	Tags = { "card", ["card-active"] = isActive },
	Attributes = { Health = hp },
	[Lucy.on "Activated"] = function() count(count() + 1) end,
	Parent = gui,

	Lucy.new "UICorner" {},
}
```

| Key | Does |
|---|---|
| `Property = value` | sets it; a ref or getter keeps it bound |
| `Tags = { "a", ["b"] = ref }` | static tags, plus tags toggled by a boolean (Vue `:class` style); or a getter returning the whole set |
| `Attributes = { Name = value }` | attributes, bound the same way |
| `[Lucy.on "Event"] = fn` | connects an event |
| `[Lucy.changed "Prop"] = fn` | calls `fn(newValue)` when a property changes |
| `[Lucy.model "Text"] = ref` | two-way binding, like `v-model` |
| `[Lucy.out "AbsoluteSize"] = ref` | the ref follows the property |
| `[Lucy.instance] = ref` | the instance, for later |
| array items | children: instances, component handles, arrays, `show` and `each` |
| `Children = { Name = child }` | named children |
| `Parent = gui` | set last |

Children keep their declared order: Lucy assigns ascending `LayoutOrder` unless
you set one.

### Conditionals and lists

```lua
Lucy.new "Frame" {
	Lucy.show(isOpen, function()
		return Lucy.new "TextLabel" { Text = "Open" }
	end, function()
		return Lucy.new "TextLabel" { Text = "Closed" }   -- optional fallback
	end),

	Lucy.each(items, function(item, index)
		return Lucy.new "TextLabel" {
			Text = function() return `{index()}. {item.name}` end,
		}
	end, { key = function(item) return item.id end }),
}
```

- `show` builds a branch when the condition flips, and destroys the old one.
- `each` keeps the instances for items that stay and only moves them; new items
  are rendered and removed ones destroyed. Items are matched by `key`, or by the
  item itself.

### Studio-built UI

`Lucy.hydrate` binds an existing instance, so designers can build in Studio and
you only add behaviour:

```lua
local hud = playerGui.HUD
Lucy.hydrate(hud.Coins) { Text = function() return tostring(coins()) end }
Lucy.hydrate(hud.Shop) { [Lucy.on "Activated"] = openShop }
```

Hydrated instances are unbound when their owner stops, never destroyed.

### Lifetime of instances

An element created inside an effect, a `show` branch, an `each` item or a scope is
destroyed when that owner goes away. If something else destroys the instance, its
bindings stop. You do not need to clean up by hand.

## Animation

Springs and tweens are reactive sources too, so you can bind them like anything else.

```lua
local open = Lucy.ref(false)
local x = Lucy.spring(function() return if open() then 0 else -320 end, 6, 0.8)

Lucy.new "Frame" {
	Position = function() return UDim2.fromOffset(x(), 0) end,
}

local fade = Lucy.tween(target, TweenInfo.new(0.25, Enum.EasingStyle.Quad))
```

- `spring(source, speed = 10, damping = 1)`: speed is how fast (natural frequency
  in Hz), damping below 1 bounces. Both can be refs.
- `tween(source, info)`: eases from where it is to each new target.
- Animates number, Vector2, Vector3, UDim, UDim2 and Color3. Colours move through
  Oklab, so red to blue passes through a clean purple. Other types snap.
- One Heartbeat connection drives every animation, and it disconnects when all of
  them are at rest.

## Coming from other libraries

| Fusion | Lucy |
|---|---|
| `scope:Value(0)`, `:get()`, `:set(x)` | `Lucy.ref(0)`, `count()`, `count(x)` |
| `scope:Computed(function(use) ... use(x) end)` | `Lucy.computed(function() ... x() end)` |
| `scope:New "Frame" { }` | `Lucy.new "Frame" { }` |
| `[OnEvent "Activated"]`, `[OnChange "Text"]`, `[Out "Text"]`, `[Ref]` | `[Lucy.on ...]`, `[Lucy.changed ...]`, `[Lucy.out ...]`, `[Lucy.instance]` |
| `scope:ForValues(list, fn)` | `Lucy.each(list, fn)` |
| `scope:Spring(x, speed, damping)` | `Lucy.spring(x, speed, damping)` |
| scopes and `doCleanup` | automatic: owned by whatever created them |

| React (react-lua) | Lucy |
|---|---|
| `useState` | `Lucy.ref` |
| `useMemo` | `Lucy.computed` (no dependency arrays) |
| `useEffect` | `Lucy.watchEffect` / `Lucy.watch` |
| re-render and reconcile | none: only changed bindings run |
| `createContext` | `app.state` and plain module state |
