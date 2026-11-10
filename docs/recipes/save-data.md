---
title: Save player data
description: Each dancer's coins and best combo loaded into the server's store when they join and saved as they change, with a Top dancers board that every player sees.
order: 7
---

# Save player data

Club Lucy keeps a profile for each dancer: their coins and their best combo.
The server loads it when they join, the player sees it at `server.me.profile`,
and every change is saved without the game asking. A Top dancers sheet shows the
best combos in the club.

It builds on the [Game folder structure](folder-structure.md): one data queue beside the one
server, a Profiles service, and a panel on the client. It uses
[Lucy.Server](../reference/server.md) for what players see and
[Lucy.DataQueue](../reference/data-queue.md) for the DataStores.

## The queue

One queue for the whole server, so every store shares the engine's budget:

```luau [src/server/Data.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

return Lucy.DataQueue.new()
```

## The Profiles service

```luau [src/server/Services/Profiles.luau]
local Players = game:GetService("Players")

local Server = script.Parent.Parent
local server = require(Server.ServerState)
local data = require(Server.Data)

local profiles = data:store("Profiles")
local bestCombos = data:ordered("BestCombos")

local DEFAULTS = { coins = 0, best = 0 }

local Profiles = {}
local stops = {} -- [player] = stops saving their profile

local function keyOf(player: Player): string
    return `u{player.UserId}`
end

local function load(player: Player)
    -- fresh: a profile must come from the store, not an old copy.
    local ok, saved = pcall(profiles.get, profiles, keyOf(player), { fresh = true })
    if not ok then
        -- Never save over a profile that could not be read.
        warn(`Profile for {player.Name} not loaded: {saved}`)
        return
    end
    if player.Parent == nil then
        return -- they left while it loaded
    end
    local me = server:player(player)
    me:set("profile", saved or table.clone(DEFAULTS))

    -- Save every change. The queue writes it when the engine has room, and
    -- what is still waiting when the server closes.
    stops[player] = me:subscribe("profile", function(profile)
        if profile then
            profiles:set(keyOf(player), profile)
        end
    end)
end

-- The game calls this when a dance ends.
function Profiles.award(player: Player, coins: number, combo: number)
    local me = server:player(player)
    if me:get("profile") == nil then
        return -- not loaded
    end
    me:batch(function()
        me:update("profile.coins", function(had)
            return had + coins
        end)
        me:update("profile.best", function(best)
            return math.max(best, combo)
        end)
    end)
    bestCombos:update(keyOf(player), function(best)
        return math.max(best or 0, combo)
    end)
end

Players.PlayerAdded:Connect(load)
for _, player in Players:GetPlayers() do
    task.spawn(load, player)
end

Players.PlayerRemoving:Connect(function(player)
    if stops[player] then
        stops[player]()
        stops[player] = nil
    end
end)

return Profiles
```

- Everything under `profile` is saved. The rest of the player's part, such as
  a round's score, lasts the session.
- `award` writes the store; the subscriber saves it and the player's App gets
  the new coins in the same frame. Earning coins many times a second costs one
  write every few seconds.
- The batch makes coins and best one change, so the profile is saved once.

A service such as `Combos` in the [Game folder structure](folder-structure.md#the-server)
calls `Profiles.award(player, hits * 10, hits)` when a dance ends.

## The board

The best combos go to `shared.top`, so every player sees them at `server.top`.
`top(10)` reads the store once, then answers from its page and refreshes it in
the background, so asking every 30 seconds is cheap:

```luau [src/server/Services/Profiles.luau]
local names = {} -- [key] = display name

local function nameOf(key: string): string
    if names[key] == nil then
        local userId = tonumber(string.sub(key, 2))
        local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
        names[key] = if ok then name else "Someone"
    end
    return names[key]
end

task.spawn(function()
    while true do
        local rows = {}
        for rank, entry in bestCombos:top(10) do
            rows[rank] = { key = entry.key, name = nameOf(entry.key), combo = entry.value }
        end
        server.state:set("shared.top", rows)
        task.wait(30)
    end
end)
```

Put this above `return Profiles`.

For boards with tabs, this week's list and each dancer's own rank, see the
[Leaderboards recipe](leaderboards.md).

## On the client

Anything that shows coins reads the profile:

```luau
local coins = app.state:ref("server.me.profile.coins")

Lucy.Text.new({
    text = function()
        return `{coins() or 0} coins`
    end,
    Parent = scene.gui,
})
```

It is `nil` until the profile arrives, a moment after the player joins.

The Top dancers sheet keeps a row per dancer by key, so a new best moves rows
rather than rebuilding them:

```luau [src/client/Panels/TopDancers.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)
local app = require(script.Parent.Parent.App)

local top = app.state:ref("server.top")
local root = app.state.root

local TopDancers = {}
local sheet = nil

local function list()
    return Lucy.new "Frame" {
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Lucy.Component.list({ Padding = UDim.new(0, 4) }),
        Lucy.each(function()
            return top() or {}
        end, function(_, index)
            return Lucy.Item.new({
                title = function()
                    local row = root.server.top[index()]
                    return if row then `{index()}. {row.name}` else ""
                end,
                description = function()
                    local row = root.server.top[index()]
                    return if row then `x{row.combo} combo` else ""
                end,
                variant = "outline",
            })
        end, { key = function(row)
            return row.key
        end }),
    }
end

function TopDancers.open()
    sheet = sheet
        or Lucy.Sheet.new({
            title = "Top dancers",
            description = "The best combos in Club Lucy.",
            children = { list() },
        })
    sheet:open()
end

return TopDancers
```

## Try it in Studio

DataStores work in Studio only when the place is published and
**Enable Studio Access to API Services** is on in Game Settings. Without that,
the queue says so once and keeps everything in memory for the session, so the
profile and the board still work while you build.
