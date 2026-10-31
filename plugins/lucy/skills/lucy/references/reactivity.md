<!-- Made by scripts/skills.ts from docs/reactivity.md. Edit the doc, not this file. -->
# Reactivity

Lucy's state is plain Luau. A ref is a function:
call it to read, call it with a value to write. There is no `.value` and no
unwrapping magic.

```luau
local combo = Lucy.ref(0)
combo()        -- 0
combo(5)       -- write: everything that read combo updates
```

When `combo` changes, only the properties and effects that read it run again.
Nothing is rebuilt and nothing is diffed.

## State

### ref

```luau
local track = Lucy.ref("Neon Nights")
track("Midnight Drop")    -- write
track(nil)                -- writing nil is fine
Lucy.trigger(queue)       -- notify after mutating a ref's table in place
```

Writing the value a ref already holds does nothing.

### computed

A cached, lazy derivation. It runs when first read, and again only when something
it read has changed.

```luau
local bonus = Lucy.computed(function()
    return combo() * 10
end)
```

Make it writable by passing `get` and `set`:

```luau
local nowPlaying = Lucy.computed({
    get = function() return `{title()} - {artist()}` end,
    set = function(value)
        local a, b = string.match(value, "^(.-) %- (.+)$")
        title(a)
        artist(b)
    end,
})
nowPlaying("Bassline Bounce - Pixel Pulse")
```

A computed that ends up with the same value stops the update there, so
`onFire = computed(function() return hype() > 90 end)` only notifies when it flips.

### reactive

A deep, reactive view of a table, for state you would rather write as fields.

```luau
local player = Lucy.reactive({ coins = 0, emotes = {} })
player.coins += 10                     -- only readers of `coins` update
Lucy.insert(player.emotes, "Robot")    -- lists: use Lucy.insert / Lucy.remove
for i, emote in player.emotes do end   -- generalized iteration and # are tracked
```

The `table` library works on raw tables, so `table.insert(player.emotes, x)` would
bypass tracking. Use `Lucy.insert` and `Lucy.remove`, or assign `emotes[#emotes + 1] = x`.
`Lucy.toRaw(proxy)` returns the plain table. Frozen tables are left as they are.

### App state

Every key in the app's store works like a ref: anything that reads a key runs
again when that key changes, and nothing else does.

```luau
local coins = app.state:ref("player.coins")
coins(coins() + 10)                  -- same as app.state:set("player.coins", ...)
app.state.root.player.coins += 10    -- the store as plain tables
```

`Lucy.batch` and `app.state:batch` are the same batch. See
[The store](./reference/store.md) for how it works and every method, and
[Work with app state](./guide/app-state.md) for a walkthrough.

## Effects

Reach for bindings and computeds first. Effects are for side effects: playing a
tween, calling game code, pushing a focus scope, playing a sound. If an effect
would only set a property, bind the property instead.

```luau
local stop = Lucy.watchEffect(function(onCleanup)
    print("coins", coins())
    onCleanup(function() end)   -- before the next run, and on stop
end)

Lucy.watch(combo, function(new, old, onCleanup) end)                 -- lazy
Lucy.watch(combo, callback, { immediate = true })                    -- run now too
Lucy.watch({ a, b }, function(values, previous) end)                 -- several sources
Lucy.watch(function() return player.coins end, callback)             -- a getter
Lucy.watch(player, callback)                                         -- deep, any change
```

- `Lucy.batch(fn)` groups writes; dependents run once, afterwards.
- `Lucy.untrack(fn)` and `Lucy.peek(source)` read without subscribing.
- `Lucy.isRef(x)` is true for refs and computeds; `Lucy.isWritable(x)` is true
  for refs and computeds made with `{ get, set }`; `Lucy.isReactive(x)` is true
  for a table from `Lucy.reactive`.
- `Lucy.trigger(ref)` tells everything that reads a ref that it changed. Use it
  after changing a table inside a ref in place, since only setting the ref
  tells them otherwise.
- `Lucy.toValue(x)` reads a ref, computed or getter, and passes plain values through.

An effect never triggers itself again by writing a ref it reads. Effects that keep
triggering each other are stopped after 100 rounds with an error, instead of
freezing the game.

## Lifetime

Everything created inside an effect, an element or a scope belongs to it, and is
cleaned up when its owner runs again or stops. You rarely need to think about it.

```luau
local scope = Lucy.effectScope()
scope:run(function()
    -- effects, computeds, elements...
    Lucy.onCleanup(function() end)
end)
scope:stop()   -- stops all of it
```

Code with no owner, such as the top of a client script, can still use `watch`,
`watchEffect`, elements and components. They last until you stop or destroy
them. Only composables need an owner.

## Composables

A composable is a plain function, named `useX`, that creates refs, computeds and
effects and returns them. Call it inside a component's render, an effect or a
scope: what it creates stops with that owner. Called anywhere else, it errors.

```luau
local density = Lucy.useDensity(app)                     -- "default" | "touch" | "tv"
local height = Lucy.useMetric(app, "ControlMd")          -- pixels, follows density
local gap = Lucy.useResponsive(app, { touch = 16, default = 8 })
Lucy.useBackHandler(app, isOpen, function() close() return true end)
Lucy.useFocusScope(app, isOpen, { root = panel })
Lucy.useUiSound(app, { activate = playClick })           -- the game's own sounds
local board = Lucy.useTable({ data = dancers, columns = columns })  -- sorted rows
Lucy.useWhile(isOpen, function() return signal:Connect(onBeat) end)  -- only while open
local timer = Lucy.useCountdown(setEndsAt)                 -- timer.remaining(), timer.done()
```

Write your own the same way: take refs or getters, return refs or computeds, and
register cleanup with `Lucy.onCleanup`.

## Declarative UI

`Lucy.new` creates an instance. Any property can be a ref, a computed or a getter.

```luau
local hypes = Lucy.ref(0)

Lucy.new "TextButton" {
    Size = UDim2.fromOffset(200, 40),
    Text = function() return `Hyped {hypes()} times` end,
    Tags = { "card", ["card-active"] = isActive },
    Attributes = { Hype = hype },
    [Lucy.on "Activated"] = function() hypes(hypes() + 1) end,
    Parent = gui,

    Lucy.new "UICorner" {},
}
```

| Key | Does |
|---|---|
| `Property = value` | sets it; a ref or getter keeps it bound |
| `Tags = { "a", ["b"] = ref }` | static tags, plus tags toggled by a boolean; or a getter returning the whole set |
| `Attributes = { Name = value }` | attributes, bound the same way |
| `[Lucy.on "Event"] = fn` | connects an event |
| `[Lucy.changed "Prop"] = fn` | calls `fn(newValue)` when a property changes |
| `[Lucy.model "Text"] = ref` | binds both ways |
| `[Lucy.out "AbsoluteSize"] = ref` | the ref follows the property |
| `[Lucy.instance] = ref` | the instance, for later |
| array items | children: instances, component handles, arrays, `show` and `each` |
| `Children = { Name = child }` | named children |
| `Parent = gui` | set last |

Children keep their declared order: Lucy assigns ascending `LayoutOrder` unless
you set one.

### Conditionals and lists

```luau
Lucy.new "Frame" {
    Lucy.show(isOpen, function()
        return Lucy.new "TextLabel" { Text = "Booth open" }
    end, function()
        return Lucy.new "TextLabel" { Text = "Booth closed" }   -- optional fallback
    end),

    Lucy.each(queue, function(track, index)
        return Lucy.new "TextLabel" {
            Text = function() return `{index()}. {track.title}` end,
        }
    end, { key = function(track) return track.id end }),
}
```

- The condition and the list can be a ref, a computed or a getter.
- `render` returns an Instance, a component, or a list of them.
- `show` builds a branch when the condition flips, and destroys the old one.
- `each` keeps the instances for items that stay and only moves them; new items
  are rendered and removed ones destroyed. Items are matched by `key`, or by the
  item itself.

### UI built in Studio

`Lucy.hydrate` binds an existing instance, so designers can build in Studio and
you only add behaviour:

```luau
local hud = playerGui.HUD
Lucy.hydrate(hud.Coins) { Text = function() return tostring(coins()) end }
Lucy.hydrate(hud.EmoteShop) { [Lucy.on "Activated"] = openEmoteShop }
```

Hydrated instances are unbound when their owner stops, never destroyed.

### Lifetime of instances

An element created inside a component's render, an effect, a `show` branch, an
`each` item or a scope belongs to it. When that owner stops, the element's
bindings stop and then the element is destroyed, so you never clean up by hand.

To remove an element early, stop its owner, which is what `show` and `each` do
for you. If you destroy an owned element yourself, its bindings keep running
until the owner stops.

An element created outside any owner stops its bindings when the instance is
destroyed.

### Components

Lucy's components take refs, computeds and getters for any state key, and bind
writable ones both ways: `Lucy.Switch.new({ checked = music })`. See
[Components](./components/index.md#reactive-props), and
[Writing a component](./components/index.md#writing-a-component) for building your own.

## Animation

Springs and tweens are reactive sources too, so you can bind them like anything else.

```luau
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
- When the player asks for reduced motion, springs and tweens of positions and
  sizes jump; colour and number tweens still fade. See
  [Accessibility](reference/accessibility.md#reduce-motion).

To make something pop when a value changes, see the [HUD recipe](recipes/hud.md).
