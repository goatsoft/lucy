---
title: Auras
description: Effects worn in the world, on a character or at a point, that every player sees, with a budget so a full server stays smooth.
order: 4
---

# Auras

An aura is an effect worn in the world: a glow that grows with a player's rank,
wings bought for half an hour, sparks round whoever is on a streak. The server
says who wears what; every player's App draws it on the right character, puts
it back after a respawn, and takes it off when its time is up. Lucy comes with
`glow`, and you can add your own types.

<!-- preview world animate="2.0" fps="12" warmup="0.6" -->
<figure class="example-preview example-screen"><img class="example-light" src="/images/examples/guide-auras-light.webp" alt="Auras example" loading="lazy"><img class="example-dark" src="/images/examples/guide-auras-dark.webp" alt="Auras example" loading="lazy"></figure>

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local app = Lucy.App.new()

-- A dancer, and the camera on them
local look = Instance.new("HumanoidDescription")
look.HeadColor, look.TorsoColor = Color3.fromRGB(234, 184, 146), Color3.fromRGB(40, 40, 52)
look.LeftArmColor, look.RightArmColor = look.HeadColor, look.HeadColor
look.LeftLegColor, look.RightLegColor = look.TorsoColor, look.TorsoColor
local dancer = Players:CreateHumanoidModelFromDescription(look, Enum.HumanoidRigType.R15)
dancer:PivotTo(CFrame.new(0, 503, 0) * CFrame.Angles(0, math.pi, 0))
dancer.HumanoidRootPart.Anchored = true
dancer.Parent = workspace
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 503, -10), Vector3.new(0, 502.5, 0))

-- A gold glow on them
Lucy.Aura.new({ type = "glow", character = dancer, token = "Warning" })
```

That is one aura on its own. In a game, the server decides who wears what and
every App follows along, as below.

## Who wears what

On the server, put an aura on a player (or a bot) with `Lucy.Aura.wear`, and
take it off with `Lucy.Aura.take`. A timed aura takes itself off:

```luau
local server = Lucy.Server.new()

-- Bought for 30 minutes
Lucy.Aura.wear(server, player, "glow", {
    options = { token = "Warning", size = 8 },
    seconds = 30 * 60,
})

-- A rank glow that stays on until the game takes it off
Lucy.Aura.wear(server, player, "rankGlow", { options = { rank = 3 } })
Lucy.Aura.take(server, player, "rankGlow")

-- Everything a player wears
Lucy.Aura.take(server, player)

-- A bot, by an id of its own
Lucy.Aura.wear(server, "bot_3", "glow")
```

A player (or their UserId) is kept as `u<UserId>`, the same key `Lucy.Server`
keeps players under, and `Lucy.Aura.idOf(player)` gives it. Any other id is
used as it is, so give bots ids with a letter in them: an id that is only
digits, or has a dot, is refused, since the store would read it as a list
index or a path.

Wearing a type again replaces it, with the new options and a new clock. Lucy
only draws: why someone wears an aura, and for how long, is your game's to
decide. A clock that stops while a player is away, a bonus an aura gives, a
price: keep those in your game and call `wear` and `take` as they change.

## Drawing them on every client

In the client script that makes your App, follow the auras once:

```luau
local app = Lucy.App.new({ server = true })

Lucy.Aura.follow(app, {
    -- Bots have ids of their own; players (u<UserId>) are found when this is left out
    resolve = function(id)
        local bot = workspace.Crowd:FindFirstChild(id)
        if bot then
            return bot
        end
        local userId = tonumber(string.match(id, "^u(%d+)$"))
        local player = userId and Players:GetPlayerByUserId(userId)
        return player and player.Character
    end,
    -- No auras while the cutscene plays
    hidden = app.state:ref("ui.cutscene.playing"),
})
```

Every aura goes on its character, comes back after a respawn, plays its
opening when it is put on and its closing when it comes off, and goes with the
App.

## Options

| Option | Default | What it does |
|---|---|---|
| `resolve` | the player a `u<UserId>` id names | `(id) -> Model?`: the character an id names |
| `hidden` | `false` | A ref, getter or boolean: hides every aura while true |
| `max` | `12` | How many auras run at once, nearest to the camera first |
| `near` | `40` | Studs from the camera within which an aura is at full strength |
| `far` | `90` | Studs beyond which an aura is off |
| `path` | `"server.auras"` | Where in the store the auras are |

With twenty dancers in view, the nearest `max` run and the rest stop, and
auras fade out between `near` and `far`, as nameplates do. One budget covers
every type, so a server full of wings costs what the budget says.

When the player asks for reduced motion, an aura's opening jumps to its end,
its loop holds still and its sparks thin out.

## One aura on its own

`Lucy.Aura.new` puts one aura on a character, or at a point, with no store:
a burst of sparks where a prize lands, a glow on a statue.

```luau
local aura = Lucy.Aura.new({
    type = "glow",
    position = workspace.Stage.Spot.Position,
    token = "Primary",
})

aura:finish()   -- plays the closing, then goes
aura:destroy()  -- goes at once
```

| Prop | What it does |
|---|---|
| `type` | The aura type: `glow`, or one you registered |
| `character` | The Model it is worn on |
| `position` | Or the Vector3 it stands at |
| `app` | The App whose theme it uses, and with which it goes (the current App) |

The rest of the props are the type's options. `aura:setStrength(0.5)` dims it
by hand; at `0` it is off.

## glow

A soft halo round the wearer, sparks rising off it and a light, in a theme
colour. It breathes while it runs.

| Option | Default | What it does |
|---|---|---|
| `token` | `"Primary"` | The theme colour, such as `"Warning"` for gold |
| `size` | `12` | The halo's size in studs, round the whole body |
| `sparks` | `20` | Sparks a second at full strength; `0` for none |
| `light` | `2.5` | The light's brightness; `0` for none |
| `at` | `"WaistCenterAttachment"` | The attachment it is centred on |

## Add your own type

A type only builds and animates; the base does the rest. Register it once, on
every client, before the auras are followed:

```luau
Lucy.Aura.register("halo", {
    intro = 0.5,   -- seconds the opening takes
    outro = 0.4,   -- seconds the closing takes
    loop = true,   -- keeps running after the opening
    defaults = { token = "Warning" },
    build = function(ctx)
        local ring = Lucy.new("Part")({
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.1, 2, 2),
            Material = Enum.Material.Neon,
            Color = ctx.color(ctx.option("token")),
            CanCollide = false,
            Massless = true,
            Transparency = function()
                local open = math.min(ctx.intro() / 0.5, 1) * (1 - ctx.outro() / 0.4)
                return 1 - 0.8 * open * ctx.strength()
            end,
            Parent = ctx.root,
        })
        -- Over the head, turning slowly
        Lucy.new("Weld")({
            Part0 = ctx.part("Head"),
            Part1 = ring,
            C0 = function()
                return CFrame.new(0, 1.4, 0) * CFrame.Angles(0, ctx.elapsed(), math.pi / 2)
            end,
            Parent = ring,
        })
    end,
})
```

`build` runs once. What it binds follows the aura from then on:

| On `ctx` | What it is |
|---|---|
| `root` | A Model in the character (or the world, for a point) for the aura's parts |
| `character` | The character, or `nil` at a point |
| `attachment(name)` | An attachment of the aura's own where the character's attachment of that name is; put emitters, beams and lights on these |
| `part(name)` | The character's part of that name, to weld a model to |
| `intro()` | Seconds into the opening |
| `elapsed()` | Seconds running, for a type that loops |
| `outro()` | Seconds into the closing, `0` until it closes |
| `strength()` | `0` to `1`, from distance and the budget |
| `reducedMotion()` | `true` when the player asked for less motion |
| `option(name)` | An option, or the type's default |
| `color(token)` | A theme colour |
| `animate(rig, id)` | Plays an animation on a rigged model, looped; held still with reduced motion |
| `give(item)` | Cleaned up with the aura: a connection or a stop function |

Wings and other moving parts are a rigged model built in Blender, welded with
`ctx.part("UpperTorso")` and played with `ctx.animate(wings, "rbxassetid://...")`.
Everything the type makes in `root`, on its attachments or through `give` goes
when the aura goes.
