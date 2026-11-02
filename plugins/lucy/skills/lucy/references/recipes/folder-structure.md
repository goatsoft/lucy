<!-- Made by scripts/skills.ts from docs/recipes/folder-structure.md. Edit the doc, not this file. -->
# Game folder structure

A suggested layout for your game folder. A game soon has more UI than one
script can hold, so this layout gives each kind of thing Lucy has a folder of
its own: a new file has an obvious home and every `require` points the same
way. The other recipes are single scripts to keep them short; in a game, their
parts go in these folders.

## The folders

```text
src/
  client/                  StarterPlayerScripts.Client
    init.client.luau       starts everything, in order
    App/
      init.luau            makes the one App and returns it
      Theme.luau           the game's themes
    Utils/                 plain functions: no state, no UI of their own
    Features/              the game on this client, as app state
    Composables/           useX functions shared by scenes, panels and boards
    Components/            the game's own components
    World/                 UI on parts and over heads
    Panels/                sheets and dialogs: the shop, the inventory
    Scenes/                one file per scene: Title, Hud, Pause
  server/                  ServerScriptService.Server
    init.server.luau       starts everything, in order
    ServerState.luau       makes the one Lucy.Server and returns it
    Services/              the game: rounds, profiles, the shop's stock
    Requests/              what players may ask for, a file per group
  shared/                  ReplicatedStorage.Shared: data both sides read
```

On the client:

| Folder | Holds |
|---|---|
| `App` | The App, its themes, and the action sets more than one scene uses |
| `Utils` | Plain functions that keep no state and build no UI: formatting a time, a request whose answer becomes a toast. One function or a small table of them per file |
| `Features` | Game logic on the client: keys in `app.state`, remotes, server requests, timers. A feature makes no instances |
| `Composables` | `useX` functions that turn the store and features into what UI shows (see [Share logic with composables](../guide/composables.md)) |
| `Components` | The game's own components (see [Build a component](../guide/components.md)) and small builders used in more than one place |
| `World` | Surfaces and billboards: boards on the walls, name tags (see [UI in the world](../guide/world-ui.md)) |
| `Panels` | A module per Sheet or Dialog, with an `open` function |
| `Scenes` | A module per scene, which registers itself when required (see [Build screens with scenes](../guide/scenes.md)) |

A file may require Lucy, `Shared`, and the folders above its own in this
table. So nothing requires a scene, and a feature never knows how it is drawn.
When two scenes need the same thing, it moves up the table rather than one
scene requiring the other.

On the server, a service is the game and knows nothing of requests. A request
file checks what a player sent and calls a service; the service writes what
players see to the server's state (see
[Share state with the server](../guide/server.md)).

## Rojo

```json [default.project.json]
{
  "name": "club-lucy",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" },
      "Packages": { "$path": "Packages" }
    },
    "ServerScriptService": {
      "Server": { "$path": "src/server" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/client" }
      }
    }
  }
}
```

## The App

One module makes the App and returns it. Every other client file gets the App
by requiring it, so no script waits on `Lucy.App.current()` and the order the
scripts start in never matters.

```luau [src/client/App/init.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local app = Lucy.App.new({
    themes = require(script.Theme),
    theme = "club",
    server = true,
})

-- Keys that open menus, used by more than one scene.
app.actions:define("menus", {
    inventory = { Enum.KeyCode.I, Enum.KeyCode.DPadUp },
})

return app
```

```luau [src/client/App/Theme.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)
local Tokens = Lucy.Tokens

local themes = Tokens.themesFor("slate", { primary = "violet" })
themes.club = table.clone(themes.dark)
themes.club.Background = Tokens.oklch(0.16, 0.04, 270)

return themes
```

## A util

A util takes what it needs and gives back a value, or does one thing and
forgets it. If it starts to keep state, it is a feature; if it builds UI, it is
a component.

```luau [src/client/Utils/formatTime.luau]
-- 75 -> "1:15"
return function(seconds: number): string
    local whole = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", whole // 60, whole % 60)
end
```

## A feature

A feature owns some keys in the store and says which at the top. Scenes and
boards read those keys; only the feature writes them.

```luau [src/client/Features/Combo.luau]
--[[
    The player's combo, at combo.* in app.state:
      combo.count   hits in a row
      combo.best    the most in a row this session
    Hits go to the server once a second, as the combo.hits request.
]]
local app = require(script.Parent.Parent.App)

app.state:set("combo", { count = 0, best = 0 })

local Combo = {}
local unsent = 0

function Combo.hit()
    unsent += 1
    app.state:update("combo.count", function(count)
        return count + 1
    end)
    app.state:update("combo.best", function(best)
        return math.max(best, app.state:get("combo.count"))
    end)
end

function Combo.miss()
    app.state:set("combo.count", 0)
end

task.spawn(function()
    while true do
        task.wait(1)
        if unsent > 0 then
            app.server:send("combo.hits", unsent)
            unsent = 0
        end
    end
end)

return Combo
```

## A composable

The words and looks a feature's state turns into, shared by the HUD and a
board on the stage:

```luau [src/client/Composables/useCombo.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

return function(app: Lucy.App)
    local count = app.state:ref("combo.count")
    return {
        count = count,
        hot = Lucy.computed(function()
            return count() >= 10
        end),
        label = Lucy.computed(function()
            return if count() >= 10 then `x{count()} on fire` else `x{count()}`
        end),
    }
end
```

## A panel

A panel builds its Sheet or Dialog the first time it opens and keeps it, so it
opens at once after that and keeps its place between visits.

```luau [src/client/Panels/Inventory.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)
local app = require(script.Parent.Parent.App)

local coins = app.state:ref("server.me.coins")

local Inventory = {}
local sheet = nil

function Inventory.open()
    sheet = sheet
        or Lucy.Sheet.new({
            title = "Inventory",
            children = {
                Lucy.Text.new({
                    text = function()
                        return `{coins() or 0} coins`
                    end,
                }),
            },
        })
    sheet:open()
end

return Inventory
```

## A scene

A scene module registers its scene and returns nothing anyone uses. Its hotkeys
go with it.

```luau [src/client/Scenes/Hud.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)
local Client = script.Parent.Parent
local app = require(Client.App)
local useCombo = require(Client.Composables.useCombo)
local Inventory = require(Client.Panels.Inventory)

app.actions:on("inventory", Inventory.open)

app.scenes:register("Hud", {
    layer = "overlay",
    build = function(scene)
        local combo = useCombo(app)
        Lucy.Text.new({ text = combo.label, Parent = scene.gui })
        Lucy.Button.new({
            text = "Inventory",
            hint = "inventory",
            onClick = Inventory.open,
            Parent = scene.gui,
        })
    end,
})

return {}
```

## Start it

The client script requires the App, then every feature (so their keys are in
the store before anything reads them), every board in `World`, and every
scene. Panels, composables and components load when something requires them.

```luau [src/client/init.client.luau]
local app = require(script.App)

local function requireAll(folder: Instance)
    for _, module in folder:GetChildren() do
        if module:IsA("ModuleScript") then
            require(module)
        end
    end
end

requireAll(script.Features)
requireAll(script.World)
requireAll(script.Scenes)

app.scenes:show("Hud")
```

## The server

The server's state is one module too, so services and requests share it:

```luau [src/server/ServerState.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

return Lucy.Server.new({
    state = { shared = { show = { phase = "Lobby" } } },
})
```

```luau [src/server/Services/Combos.luau]
local server = require(script.Parent.Parent.ServerState)

local Combos = {}

function Combos.add(player: Player, hits: number)
    server:player(player):update("score", function(score)
        return (score or 0) + hits * 10
    end)
end

return Combos
```

A request file checks everything that arrives, since a client can send
anything, and leaves the game to the service:

```luau [src/server/Requests/ComboRequests.luau]
local Server = script.Parent.Parent
local server = require(Server.ServerState)
local Combos = require(Server.Services.Combos)

server:handle("combo.hits", function(player, hits)
    if type(hits) ~= "number" or hits % 1 ~= 0 or hits < 1 or hits > 20 then
        return false
    end
    Combos.add(player, hits)
    return true
end)

return {}
```

```luau [src/server/init.server.luau]
require(script.ServerState)

for _, folder in { script.Services, script.Requests } do
    for _, module in folder:GetChildren() do
        if module:IsA("ModuleScript") then
            require(module)
        end
    end
end
```

## Growing it

- A feature with several parts becomes a folder with an `init.luau`, as any
  module can: `Features/Rhythm/init.luau` beside `Features/Rhythm/Judging.luau`.
  Its art, if it draws to a canvas, goes in `Components`.
- A scene that grows panels of its own keeps them in `Panels`, named for what
  they show, not for the scene: another scene may want them later.
- Keep the App's own keys in a comment at the top of `App/init.luau`, as each
  feature does for its own: the store is shared, and that comment is how a
  reader finds who writes a key.
