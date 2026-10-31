---
title: Settings menu that saves
description: A volume slider and a theme picker bound to app state, loaded when the player joins and saved when they leave.
order: 2
---

# Settings menu that saves

A settings screen with a volume slider and a theme picker. Each control is
bound to app state, the game reads the same state, and the server keeps the
settings between sessions.

Lucy's part is the menu and the state. Saving is your game's: Lucy never
talks to the server. Here the server keeps the settings in a DataStore and the
client asks for them when it starts.

## The menu

```luau [StarterPlayerScripts/UI.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

-- Ask the server for this player's saved settings before making the App.
local saved = ReplicatedStorage:WaitForChild("LoadSettings"):InvokeServer()

local app = Lucy.App.new({
    theme = saved.theme,
    state = { settings = { volume = saved.volume } },
})

app.scenes:register("Settings", {
    build = function(scene)
        Lucy.Stack.new({
            size = UDim2.fromScale(1, 1),
            align = "center",
            justify = "center",
            children = {
                Lucy.Panel.new({
                    title = "Settings",
                    maxWidth = 400,
                    children = {
                        -- Each control is bound to a value in state, both ways.
                        Lucy.Text.new({ text = "Volume", variant = "label" }),
                        Lucy.Slider.new({ value = app.state:ref("settings.volume"), showValue = true }),
                        Lucy.Text.new({ text = "Theme", variant = "label" }),
                        Lucy.Select.new({
                            items = { { value = "dark", label = "Dark" }, { value = "light", label = "Light" } },
                            value = app.state:ref("theme"), -- pick Light and the whole UI switches
                        }),
                    },
                }),
            },
            Parent = scene.gui,
        })
    end,
})

app.scenes:goTo("Settings")

-- The game reads the same state. No glue code in between.
app.state:subscribe("settings.volume", function(volume)
    SoundService.Music.Volume = volume / 100
end)
```

On a screen the player moves around with keys or a gamepad, give the scene a
`defaultFocus` that returns what to select first. See
[Input and focus](../architecture.md#input-and-focus).

## Tell the server

Send the settings when they change. Dragging the slider changes the volume many
times a second, so wait a moment and send once:

```luau
local SaveSettings = ReplicatedStorage:WaitForChild("SaveSettings")
local waiting = false

local function saveSoon()
    if waiting then
        return
    end
    waiting = true
    task.delay(1, function()
        waiting = false
        SaveSettings:FireServer(app.state:get("settings.volume"), app.state:get("theme"))
    end)
end

app.state:subscribe("settings.volume", saveSoon)
app.state:subscribe("theme", saveSoon)
```

Subscribers are for work outside the UI like this; see
[Subscribers](../reference/store.md#subscribers).

## The server

The server loads a player's settings the first time their client asks, keeps
the latest the client sends, and saves them when the player leaves.

```luau [ServerScriptService/Settings.server.luau]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULTS = { volume = 50, theme = "dark" }
local settings = {} -- [player] = their settings

local load = Instance.new("RemoteFunction")
load.Name = "LoadSettings"
load.Parent = ReplicatedStorage

local save = Instance.new("RemoteEvent")
save.Name = "SaveSettings"
save.Parent = ReplicatedStorage

-- GetDataStore errors in Studio when the place isn't published. The menu still
-- works then, with the defaults, and nothing is saved.
local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, "Settings")
if not ok then
    warn(`Settings won't be saved: {store}`)
    store = nil
end

load.OnServerInvoke = function(player)
    if settings[player] == nil then
        local found, data = false, nil
        if store then
            found, data = pcall(store.GetAsync, store, tostring(player.UserId))
        end
        settings[player] = if found and type(data) == "table" then data else table.clone(DEFAULTS)
    end
    return settings[player]
end

-- A client can send anything, so check it before keeping it.
save.OnServerEvent:Connect(function(player, volume, theme)
    if type(volume) ~= "number" or (theme ~= "dark" and theme ~= "light") then
        return
    end
    settings[player] = { volume = math.clamp(math.round(volume), 0, 100), theme = theme }
end)

local function saveFor(player)
    local data = settings[player]
    settings[player] = nil
    if data and store then
        pcall(store.SetAsync, store, tostring(player.UserId), data)
    end
end

Players.PlayerRemoving:Connect(saveFor)

-- When the server shuts down, save everyone still in the game.
game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        saveFor(player)
    end
end)
```

DataStores work in Studio only when the place is published and
**Enable Studio Access to API Services** is on in Game Settings. Without that,
the menu still works with the defaults, and the server warns that nothing is
saved.

A game that already saves player data should keep settings with the rest of it
and send them the same way.
