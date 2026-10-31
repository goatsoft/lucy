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
    interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
    dances = { Enum.KeyCode.G, Enum.KeyCode.ButtonR1 },
})

app.actions:define("menus", {
    inventory = { Enum.KeyCode.I, Enum.KeyCode.ButtonL1 },
    shop = { Enum.KeyCode.B, Enum.KeyCode.DPadRight },
})
```

Each list holds keyboard keys, mouse buttons and gamepad buttons together. Action
names are unique in an app, and they never clash with component ids or state
paths. Defining a set again adds to it. `movement` is the only set name Lucy
uses itself (see below).

Keep the keys that open menus in a set of their own. The usual next step is to
switch `gameplay` off while a menu is open, and a key in that set could then
not close the menu it opened.

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

Define the action first: `on` errors for a name that isn't defined. The
function runs each time the action is pressed. Call `stop()` to stop
listening. Called inside a component's render or an effect, it stops by itself
with that owner; at the top of a script it listens until you call `stop()`.
Actions never fire while the player is typing in a text box.

## Touch players

Touch screens have no keys, so an action alone leaves a touch player no way in.
Give each one a button too, calling the same function, for example in a HUD
[overlay scene](scenes.md):

```luau
local function toggleShop()
    shop:toggle()
end

app.actions:on("shop", toggleShop)

Lucy.Button.new({
    icon = "lucide:shopping-cart",
    text = "Shop",
    hint = { keyboard = Enum.KeyCode.B, gamepad = Enum.KeyCode.DPadRight },
    onClick = toggleShop,
    Parent = scene.gui,
})
```

## Keys Roblox keeps

Escape and a gamepad's Start (menu) button always open Roblox's own menu, and a
game cannot stop that, so don't give them actions: a pause menu can't open on
Start. A gamepad's Select (View) button may be Roblox's on some platforms too,
so avoid it. Lucy goes back on B and Backspace instead; see
[Back keys](../architecture.md#back-keys).

For a pause menu, open it from the game screen's `onBack`, so B and Backspace
pause, and give players a pause button they can see:

```luau
app.scenes:register("Game", {
    build = function(scene)
        Lucy.Button.new({
            icon = "lucide:pause",
            text = "Pause",
            hint = { keyboard = Enum.KeyCode.Backspace, gamepad = Enum.KeyCode.ButtonB },
            onClick = function()
                app.scenes:push("Pause")
            end,
            Parent = scene.gui,
        })
    end,
    onBack = function()
        app.scenes:push("Pause")
    end,
})
```

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
have released it. Disabling a set that isn't defined yet is fine: when you
define it, it starts off until released. `disable` takes several sets and gives one `release`.
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

`app:modalOpen()` is true while any modal dialog, sheet or popup is open, or a
modal scene has been pushed (`app.scenes:push`, such as a pause menu), and it
updates anything that reads it. Panels opened with `modal = false`, overlay
scenes such as a HUD, and screens such as a title screen never count. To keep
gameplay keys off on a title screen too, check the current screen as well:

```luau
local current = app.state:ref("scenes.current") -- nil until the first goTo

Lucy.effectScope():run(function()
    Lucy.useWhile(function()
        return app:modalOpen() or current() ~= "Game"
    end, function()
        return app.actions:disable("gameplay", "movement")
    end)
end)
```

Actions in a set you leave on, such as your menu keys, still fire while a
dialog is open. To ignore one while a confirm is up, check
`app.state:ref("overlay.top")`, as below.

Put it together with [`useWhile`](../reference/composables.md#usewhile) to switch
gameplay keys and movement off while a menu is open:

```luau
Lucy.effectScope():run(function()
    Lucy.useWhile(function()
        return app:modalOpen()
    end, function()
        return app.actions:disable("gameplay", "movement")
    end)
end)
```

`useWhile` belongs to whatever runs it, and stops with it. In a client script
nothing does, so run it in an effect scope as above; it then lasts as long as
the script. Inside a component's render or a scene's `build`, call it directly.

Each part is your choice. A dance menu that lets players keep moving switches
off only `gameplay`:

```luau
local top = app.state:ref("overlay.top") -- the id of the newest overlay

Lucy.effectScope():run(function()
    Lucy.useWhile(function()
        return top() == "dances"
    end, function()
        return app.actions:disable("gameplay")
    end)
end)
```
