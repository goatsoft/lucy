<!-- Made by scripts/skills.ts from docs/reference/store.md. Edit the doc, not this file. -->
# The store

Every App has one store, `app.state`. It holds the state of the UI (every
component, the scene stack, toasts, input, theme) and any game data you put in
it. Bindings, computeds and effects that read the store run again when what they
read changes, and nothing else does.

This page explains how the store is built, lists every method, and sets out the
rules. For a walkthrough, see [Work with app state](../../../lucy/references/guide/app-state.md).

## What it holds

The store is one tree of plain tables. Lucy keeps its own state at a few top
level keys; the rest is yours.

```
app.state
├─ ui            one table per component, at ui.<id>
│  ├─ dance      { text = "Dance", variant = "default", disabled = false, ... }
│  └─ music      { label = "Music", value = 80, min = 0, max = 100, ... }
├─ scenes        { current = "Title", stack = { ... }, visible = { ... } }
├─ toasts        the toasts on screen, in order
├─ input         { device, mode, density, orientation, breakpoint, viewport, touch, gamepad, keyboard }
├─ theme         "dark"
├─ density       "default" | "touch" | "tv"
└─ player        yours: anything you pass in `state` or set later
```

Pass your starting data to `App.new`:

```luau
local app = Lucy.App.new({
    state = { player = { coins = 0, emotes = {} }, settings = { lights = true } },
})
```

Writing Lucy's keys does what you would expect: `app.state:set("theme", "light")`
switches the theme, and `app.state:set("ui.dance.disabled", true)` disables that
button.

## Paths

A path names one place in the tree, with dots between the keys:

- `"player.coins"` is the `coins` key of the `player` table.
- A part made only of digits is an array index: `"player.emotes.1.name"`.
- No path, or `nil`, is the whole tree.
- Empty parts (`"player..coins"`) are an error.

Lucy splits each path once and remembers it, so passing the same string again
costs nothing.

## How it works

### One tree, changed in place

The store keeps your data as ordinary tables and changes them in place. A write
walks its path and changes one key, so it costs the same however big the tree
is. Each key is something a binding can follow, the same as a `Lucy.ref`.

### Writes store a copy and compare

`set` never keeps the table you pass in. It copies it into the tree, comparing
with what is there key by key:

- a key whose value did not change notifies nobody;
- a key that changed notifies only the bindings that read that key;
- a table written over a table is updated in place, key by key, so writing the
  same data again costs a comparison and nothing more.

So it is fine to set a whole table whenever something might have changed. Only
the keys that really changed cause any work.

Tables with a metatable (a handle, a class, an Instance) are stored as they are,
not copied or walked.

### Who hears about a write

A write to `player.coins` reaches three kinds of reader:

| Reader | Hears about |
|---|---|
| A binding, computed or effect that read `player.coins` | changes to that key only |
| One that read the whole `player` table (`state:ref("player")`, a loop, `#`) | changes anywhere under `player` |
| A subscriber on `player.coins`, `player` or the root | changes at its path, above it or below it |

Bindings and effects run first, then subscribers, in the order they subscribed.

When a table leaves the tree (removed, or replaced by a value), everyone reading
a key inside it runs again and sees `nil`. When the path comes back, they pick it
up.

### Reads hand out frozen copies

`get` returns a frozen copy of a table: it never changes under you, and
assigning to it throws an error. Lucy builds the copy when you ask for it and
hands out the same copy until something inside changes. Tables inside it that
did not change are shared with the previous copy.

Reading a single key (through `state:ref`, `state.root` or a binding) copies
nothing. Reading a whole table that just changed builds a new copy, so prefer
single keys for values you read often.

## Methods

| Method | Does |
|---|---|
| `state:get(path?)` | The value at `path`. Tables come back as frozen copies. Does not follow. |
| `state:set(path?, value)` | Stores a copy of `value` at `path`, creating missing tables on the way. |
| `state:update(path, fn)` | `set(path, fn(get(path)))`. `fn` gets a frozen copy for a table: return a new one. |
| `state:merge(path, patch)` | Sets each key of `patch` in the table at `path`, keeping the others. Creates the table if missing. |
| `state:remove(path)` | Sets `path` to `nil`. |
| `state:ref(path?)` | A writable ref onto `path`. Reading follows it; writing calls `set`. |
| `state.root` | The tree as tables you can index, loop over and assign to. |
| `state:subscribe(path?, fn)` | Calls `fn(new, old)` when the value at `path` changes. Returns a function that stops it. |
| `state:batch(fn)` | Runs `fn`; bindings and subscribers run once, after it. The same as `Lucy.batch`. |
| `state:scope(prefix)` | The same methods with every path under `prefix`. |

## Reading

There are three ways to read, for three jobs:

```luau
-- Once, now: a value or a frozen copy.
local coins = app.state:get("player.coins")

-- Following: a ref. Use it in a binding, computed or effect.
local coinsRef = app.state:ref("player.coins")
Text = function() return `Coins: {coinsRef()}` end

-- Following, written like tables.
local root = app.state.root
Text = function() return `Coins: {root.player.coins}` end
```

- **`state:ref(path)`** follows one path. On a value it follows that key; on a
  table it returns a frozen copy and follows anything under it. A path that
  does not exist yet reads as `nil` and is picked up when it appears.
- **`state.root`** follows exactly what you touch. `root.player.coins` follows
  `coins`. A loop or `#` follows the whole table. A table inside comes back as
  another view, not a copy.
- **`get`** follows nothing. Use it in callbacks and game code.

## Writing

```luau
local state = app.state

state:set("player.coins", 10)
state:update("player.coins", function(n) return n + 5 end)
state:merge("player", { coins = 0, level = 3 })
state:remove("player.level")

state.root.player.coins += 1           -- the same as set
state:ref("player.coins")(20)          -- the same as set
```

Every form goes through `set`, so they all copy, compare and notify the same
way. To change a list, copy it, change the copy and set it:

```luau
local emotes = table.clone(state:get("player.emotes"))
table.insert(emotes, { id = "moonwalk", name = "Moonwalk" })
state:set("player.emotes", emotes)
```

Only the new item notifies; the items that were already there compare equal.

## Subscribers

A subscriber runs a function when the value at its path changes. Use one for
work outside the UI: saving, sounds, analytics, telling the server. For the UI
itself, bind instead, and in UI code follow a ref or computed with `Lucy.watch`.

```luau
local stop = app.state:subscribe("player", function(new, old)
    saveQueue:push(new) -- `new` and `old` are frozen copies
end)
```

- It runs when its path changes, when a table above it is set, or when anything
  below it changes. A subscriber on `player` hears about `player.coins`.
- `new` and `old` are the values at its path; tables are frozen copies.
- If the value ends where it started (inside a batch, say), it is not called.
- Subscribers run after bindings and effects, in the order they subscribed.
- A write made inside a subscriber is delivered in a second round, after every
  subscriber of the first has run.
- An error in one subscriber is printed as a warning; the others still run.

## Batching

```luau
app.state:batch(function()
    app.state:set("player.coins", 0)
    app.state:set("player.emotes", {})
    app.state:set("ui.emoteShop.visible", false)
end)
```

Inside a batch, bindings, effects and subscribers wait. When the outermost batch
ends, each runs once with the final values. `Lucy.batch` and `state:batch` are
the same batch, so you can mix refs and store writes inside one.

## Components and the store

Each component keeps its state keys at `ui.<id>`. The keys are the component's
`defaults`; props with those names set the starting values.

- **Give it an `id`** and any code can drive it: `app.state:set("ui.dance.text", "Groove")`.
  Without one, Lucy makes one up (`button-1`, `button-2`...).
- **State already in the store wins.** If `ui.<id>` exists when the component is
  created, its keys override the defaults and props. Set a component's state
  before it exists and it starts from there. Keys given a ref are the
  exception: they start from the ref.
- **Destroying a component removes `ui.<id>`**, unless it was created with
  `persist = true`, which keeps its state for next time.
- **A ref as a prop binds both ways.** `checked = app.state:ref("settings.lights")`
  makes the Switch's `checked` key and `settings.lights` one value: a write to
  either is a write to both, inside the same `set`, before any subscriber runs.
  Any writable ref works (`Lucy.ref`, a computed with `get` and `set`).
- **A getter as a prop is followed one way.** The key takes the getter's value
  whenever it changes; a write to the key lasts until the next change.

## Scoped stores

`state:scope(prefix)` returns the same methods with every path under `prefix`.
Hand one to code that should only see its own part of the tree:

```luau
local emotes = app.state:scope("player.emotes")
emotes:set("1.plays", 3)                       -- player.emotes.1.plays
emotes:subscribe(nil, function(list) end)      -- player.emotes
local favourites = emotes:scope("favourites")  -- player.emotes.favourites
```

## Examples

### A HUD that follows game data

Game code writes the store; the HUD follows it. Neither knows about the other.

```luau
-- HUD
local coins = app.state:ref("player.coins")
local hype = app.state:ref("player.hype")

Lucy.new "Frame" {
    Parent = hud,
    Lucy.new "TextLabel" { Text = function() return `{coins()} coins` end },
    Lucy.Progress.new({ value = hype, max = 100 }),
}

-- Game code
app.state:merge("player", { coins = 120, hype = 75 })
```

### Settings bound to saved data

```luau
local app = Lucy.App.new({ state = { settings = saved or { lights = true, music = 80 } } })

Lucy.Switch.new({ label = "Club lights", checked = app.state:ref("settings.lights"), Parent = menu })
Stepper.new({ label = "Music", value = app.state:ref("settings.music"), max = 100, Parent = menu })

app.state:subscribe("settings", function(settings)
    remote:FireServer("SaveSettings", settings)
end)
```

The controls write `settings` directly; the subscriber saves the whole table,
once per change, as a frozen copy that is safe to send.

### A shop button that follows the price

```luau
local coins = app.state:ref("player.coins")
local price = 120

Lucy.Button.new({
    id = "buy-robot",
    text = `Buy Robot ({price})`,
    disabled = function()
        return coins() < price
    end,
    onClick = function()
        app.state:update("player.coins", function(n) return n - price end)
    end,
    Parent = shop,
})
```

## Rules

- **Keep one source for each value.** Bind components to store paths with refs
  instead of copying values between them.
- **Follow single keys.** `state:ref("player.coins")` is cheaper to follow than
  `state:ref("player")`, which runs again when anything in `player` changes.
- **Use `get` for one off reads,** and never to feed a binding: it does not follow.
- **Never change a table you read.** Copies from `get` are frozen; change a
  `table.clone` and set it.
- **Bind for the UI, subscribe for everything else.**
- **Batch related writes** so readers never see half of a change.
