<!-- Made by scripts/skills.ts from docs/guide/actions.md. Edit the doc, not this file. -->
# Hotkeys and modal input

Give each thing a player can do a name, such as `inventory`, and list the keys
and buttons that do it. Your code then listens for the name, never for a key, so
changing a key is one line and players on a keyboard and a gamepad share the
same code.

Actions live in sets. A set is switched on and off as a whole: turn off your
`gameplay` set while a menu is open and none of its keys do anything.

## Define actions

```luau
app.actions:define("gameplay", {
    inventory = { Enum.KeyCode.I, Enum.KeyCode.ButtonL1 },
    shop = { Enum.KeyCode.B, Enum.KeyCode.DPadRight },
    dances = { Enum.KeyCode.G, Enum.KeyCode.ButtonR1 },
})
```

Each list holds keyboard keys, mouse buttons and gamepad buttons together. Action
names are unique in an app. Defining a set again adds to it.

An optional third table sets the set's `priority` (1000 by default; higher sets
hear a key first) and `sink` (`true` stops lower sets hearing the keys it uses).

Behind the scenes each set is a Roblox `InputContext`, each action an
`InputAction` and each key an `InputBinding`, kept in a folder in the player's
`PlayerScripts`.

## Listen for an action

```luau
local stop = app.actions:on("inventory", function()
    inventory:toggle()
end)
```

The function runs each time the action is pressed. Call `stop()` to stop
listening. Called inside a component's render or an effect, it stops by itself
with that owner. Actions never fire while the player is typing in a text box.

## Change keys

```luau
app.actions:bind("inventory", { Enum.KeyCode.Tab, Enum.KeyCode.ButtonL1 })

-- several at once, such as the keys a player saved
app.actions:bind({
    inventory = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonL1 },
    shop = { Enum.KeyCode.P, Enum.KeyCode.DPadRight },
})
```

`bind` replaces the keys. Saving a player's choice is up to your game.

To show a key in your UI, `app.actions:keys("inventory")` gives the keys for the
input the player is using right now: the gamepad buttons on a gamepad, nothing
on touch, the rest otherwise. Read it in a binding and it updates when the
player picks up a controller or you change the keys.

## Switch sets off

```luau
local release = app.actions:disable("gameplay")
-- later
release()
```

Disables count: if two menus each disable `gameplay`, it comes back once both
have released it. `disable` takes several sets and gives one `release`.
`app.actions:enabled("gameplay")` tells you whether a set is on, and updates
anything that reads it.

## Stop the character moving

`movement` is a set Lucy makes for you. It holds the keys Roblox's character
controls use: W, A, S, D, the arrow keys, Space and the left stick. While it is
disabled the character does not walk or jump. Keyboard and gamepad navigation in
your UI keep working.

```luau
local release = app.actions:disable("movement")
```

Lucy never disables it on its own. Change its keys with
`app.actions:bind("movement", keys)`. It has no actions to listen for.

Roblox is moving its character controls to a new input system (the Workspace
setting `PlayerScriptsUseInputActionSystem`). Lucy works with the old and new
controls and picks the right way to hold the keys for each.

## While a menu is open

`app:modalOpen()` is true while any modal dialog, sheet or popup is open, and
updates anything that reads it. Panels opened with `modal = false` never count.

Put it together with [`useWhile`](../reference/composables.md#usewhile) to switch
gameplay keys and movement off while a menu is open:

```luau
Lucy.useWhile(function()
    return app:modalOpen()
end, function()
    return app.actions:disable("gameplay", "movement")
end)
```

Each part is your choice. A dance menu that lets players keep moving switches
off only `gameplay`:

```luau
local top = app.state:ref("overlay.top") -- the id of the newest overlay

Lucy.useWhile(function()
    return top() == "dances"
end, function()
    return app.actions:disable("gameplay")
end)
```
