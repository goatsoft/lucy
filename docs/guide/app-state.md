---
title: Work with app state
description: Keep game data in the app's store and bind UI to it with state:ref, state.root, lists and subscribers.
order: 5
---

# Work with app state

Every App has one store, `app.state`: a tree of plain tables that holds the UI's
state and, if you like, the game data the UI shows. Anything that reads a key
runs again when that key changes, and nothing else does. This guide builds a
small inventory HUD to show how to read, write and bind to it.

## Start with your data

Pass the starting tree to `App.new`. Components add their own state under `ui`
when they are created, so keep your data beside it:

```luau
local app = Lucy.App.new({
    theme = "dark",
    state = {
        player = { coins = 0, bag = {} },
        settings = { music = true },
    },
})
```

Paths are dot separated: `"player.coins"`. A part made only of digits is an
array index, so `"player.bag.1.name"` is the first item's name.

## Read and write

```luau
app.state:set("player.coins", 10)
app.state:update("player.coins", function(coins)
    return coins + 5
end)
app.state:merge("player", { coins = 0, level = 3 }) -- sets those keys, keeps the rest
app.state:remove("player.level")

local player = app.state:get("player")
print(player.coins)
```

`set` stores a copy of what you pass and compares it with what is there, key
by key. Writing an equal value notifies nobody, so it is fine to set a whole
table each time something might have changed.

`get` returns a frozen copy: it never changes under you, and assigning to it
throws an error. Lucy reuses the copy until something inside changes. Use `get`
for one off reads; to follow a value, use a ref.

## Follow a path with state:ref

`app.state:ref(path)` is a ref onto one path. Read it inside a binding and the
binding follows that path:

```luau
local coins = app.state:ref("player.coins")

Lucy.new "TextLabel" {
    Text = function()
        return `Coins: {coins()}`
    end,
    Parent = scene.gui,
}

coins(coins() + 10) -- the same as app.state:set("player.coins", ...)
```

It sees writes made from anywhere: game code calling `set`, another ref onto
the same path, or a component bound to it. A path that does not exist yet reads
as `nil`, and the ref picks it up when it appears.

### Bind a component prop

Pass a ref as a component prop and the component's key follows it both ways.
A Switch bound to `settings.music` writes the setting when clicked and moves
when the setting changes:

```luau
Lucy.Switch.new({
    label = "Music",
    checked = app.state:ref("settings.music"),
    Parent = scene.gui,
})
```

There is only one copy of the value, so nothing needs to be kept in sync.

## Use the tree like tables with state.root

`app.state.root` is the store as tables you can index, loop over and assign to.
Reading a key follows that key. Assigning goes through `set`, so bindings and
subscribers see it:

```luau
local root = app.state.root

root.player.coins += 1
for i, item in root.player.bag do
    print(i, item.name)
end
print(#root.player.bag)
```

A loop or `#` follows the whole table, so it runs again when anything in it
changes. Reading one key follows only that key.

## Show a list

`Lucy.each` makes one row per item and keeps rows by key, so when the list
changes, rows for items that stay are kept and moved, not rebuilt:

```luau
local bag = app.state:ref("player.bag")
local root = app.state.root

Lucy.new "Frame" {
    Parent = scene.gui,
    Lucy.Component.list({ Padding = UDim.new(0, 4) }),
    Lucy.each(bag, function(item, index)
        return Lucy.new "TextLabel" {
            Name = item.id,
            Text = function()
                local entry = root.player.bag[index()]
                return if entry then `{entry.name} x{entry.count}` else ""
            end,
        }
    end, { key = function(item)
        return item.id
    end }),
}
```

`item` is the item as it was when its row was made: use it for things that
never change, such as the id. For fields that do change, read the store
through `index()`, which follows the row as it moves. Then a write such as
`root.player.bag[2].count += 1` updates that one label.

To add or remove items, set the list:

```luau
local items = table.clone(app.state:get("player.bag"))
table.insert(items, { id = "bow", name = "Bow", count = 1 })
app.state:set("player.bag", items)
```

## Control components from game code

A component's state lives at `ui.<id>`. Give it an `id` and any code can drive
it without holding the handle:

```luau
Lucy.Button.new({ id = "buy", text = "Buy", Parent = scene.gui })

-- elsewhere
app.state:set("ui.buy.disabled", app.state:get("player.coins") < 100)
app.state:merge("ui.buy", { text = "Sold out", disabled = true })
```

## Run code when a value changes

Bindings keep the UI in step. For work outside the UI, such as saving,
playing a sound or telling the server, subscribe:

```luau
local stop = app.state:subscribe("player.coins", function(new, old)
    if new > old then
        coinSound:Play()
    end
end)
```

A subscriber on a table hears about changes anywhere under it, with old and new
frozen copies. Subscribers run after bindings and effects. Call the returned
function to stop.

## Write several values at once

Wrap related writes in `app.state:batch` (the same as `Lucy.batch`). Bindings
and subscribers run once at the end, with the final values:

```luau
app.state:batch(function()
    app.state:set("player.coins", 0)
    app.state:set("player.bag", {})
    app.state:set("ui.buy.disabled", true)
end)
```

A subscriber whose value ends where it started is not called at all.

## Next

- [The store](../reference/store.md): how the store works, every method and
  the rules.
- [Share logic with composables](./composables.md)
- [Reactivity](../reactivity.md): refs, computeds, effects and the rest of the
  reference.
