---
title: Prompts and proximity
description: Open the DJ Booth deck, trigger the Dance Floor radial menu from an input hint, gate the VIP mirror and hang crew tags in the world.
order: 8
---

# Prompts and proximity

Club Lucy has four world interactions built with [Prompt](../components/prompt.md),
[Tooltip](../components/tooltip.md), [Kbd](../components/kbd.md) and
[useProximity](../reference/composables/use-proximity.md).

## 1. Actions for world keys

Define the keys once in `app.actions` so every prompt and hint stays in step
across keyboard, gamepad and rebinds:

```luau
local Lucy = require(ReplicatedStorage.Lucy)

local app = Lucy.App.new({
    themes = Lucy.Tokens.themes,
})

app.actions:define("gameplay", {
    interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
    dance = { Enum.KeyCode.G, Enum.KeyCode.ButtonY },
})
```

## 2. DJ Booth hold prompt

Walk up to the Booth console to see a rounded `[E]` prompt (`Play a set`). Hold
to fill the circular ring around the key cap and open the Booth
[Sheet](../components/sheet.md). While the sheet is open, `useWhile` disables
character movement:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/recipes-proximity-interactions-light.webp" alt="Prompts and proximity example" loading="lazy"><img class="example-dark" src="/images/examples/recipes-proximity-interactions-dark.webp" alt="Prompts and proximity example" loading="lazy"></figure>

```luau
app.actions:define("gameplay", {
    interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
})

local boothOpen = Lucy.ref(false)

local boothSheet = Lucy.Sheet.new({
    app = app,
    title = "DJ Booth",
    description = "Pick a track for the club.",
    open = boothOpen,
    build = function(body)
        Lucy.Button.new({
            text = "Queue Neon Nights",
            onClick = function()
                app.toast.success("Queued Neon Nights")
                boothOpen(false)
            end,
            Parent = body,
        })
    end,
})

local scope = Lucy.effectScope()
scope:run(function()
    Lucy.useWhile(boothOpen, function()
        return app.actions:disable("movement")
    end)
end)

Lucy.Prompt.new({
    app = app,
    target = workspace.Booth.Console,
    action = "interact",
    actionText = "Play a set",
    objectText = "DJ Booth",
    distance = 10,
    hold = 0.6,
    variant = "primary",
    onTrigger = function()
        boothOpen(true)
    end,
})
```

## 3. Dance Floor proximity hint triggering a radial Menu

A proximity [Tooltip](../components/tooltip.md) on the Dance Floor shows a
circular input hint (`Kbd` with `shape = "circle"` bound to `"dance"`). Pressing
that action while the player is on the floor opens the radial dance
[Menu](../components/menu.md):

<!-- preview solo then="danceMenuOpen(true)" -->
<figure class="example-preview"><img class="example-light" src="/images/examples/recipes-proximity-interactions-2-light.webp" alt="Prompts and proximity example" loading="lazy"><img class="example-dark" src="/images/examples/recipes-proximity-interactions-2-dark.webp" alt="Prompts and proximity example" loading="lazy"></figure>

```luau
app.actions:define("gameplay", {
    dance = { Enum.KeyCode.G, Enum.KeyCode.ButtonY },
})

local danceMenuOpen = Lucy.ref(false)

local floorHint = Lucy.Tooltip.new({
    app = app,
    target = workspace.DanceFloor,
    trigger = "proximity",
    distance = 18,
    side = "top",
    variant = "inverse",
    content = function()
        return Lucy.Stack.new({
            direction = "horizontal",
            gap = "Space2",
            align = "center",
            children = {
                Lucy.Kbd.new({ app = app, action = "dance", shape = "circle", touch = "Tap" }),
                Lucy.Text.new({ text = "Pick a dance", autoWidth = true }),
            },
        })
    end,
})

local danceMenu = Lucy.Menu.new({
    app = app,
    open = danceMenuOpen,
    anchor = floorHint.body,
    variant = "radial",
    items = {
        { value = "moonwalk", label = "Moonwalk" },
        { value = "robot", label = "Robot" },
        { value = "shuffle", label = "Shuffle" },
        { value = "twirl", label = "Twirl" },
        { value = "wave", label = "Wave" },
        { value = "groove", label = "Groove" },
    },
    onSelect = function(value)
        app.toast(`Dancing: {value}`)
    end,
})

app.actions:on("dance", function()
    if floorHint.open() then
        danceMenuOpen(not danceMenuOpen())
    end
end)
```

## 4. Wardrobe mirror gated by player state

When `player.vip` is false, a proximity tooltip explains the requirement. Once
the player becomes a VIP, the tooltip hides and a Prompt takes over:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/recipes-proximity-interactions-3-light.webp" alt="Prompts and proximity example" loading="lazy"><img class="example-dark" src="/images/examples/recipes-proximity-interactions-3-dark.webp" alt="Prompts and proximity example" loading="lazy"></figure>

```luau
local isVip = app.state:ref("player.vip")

Lucy.Tooltip.new({
    app = app,
    target = workspace.Wardrobe.Mirror,
    trigger = "proximity",
    distance = 10,
    visible = function()
        return not isVip()
    end,
    text = "VIP members only",
})

Lucy.Prompt.new({
    app = app,
    target = workspace.Wardrobe.Mirror,
    action = "interact",
    actionText = "Change outfit",
    objectText = "Wardrobe Mirror",
    distance = 10,
    enabled = isVip,
    onTrigger = function()
        app.scenes:goTo("Wardrobe")
    end,
})
```

## 5. Crew name tags and restyling Roblox prompts

Hang `always` tooltips over crew members, and restyle any remaining Roblox
`ProximityPrompt` instances in one call:

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/recipes-proximity-interactions-4-light.webp" alt="Prompts and proximity example" loading="lazy"><img class="example-dark" src="/images/examples/recipes-proximity-interactions-4-dark.webp" alt="Prompts and proximity example" loading="lazy"></figure>

```luau
for _, member in { { name = "Nova", role = "Host" }, { name = "Kai", role = "Lights" } } do
    Lucy.Tooltip.new({
        app = app,
        target = workspace.Crew[member.name].Head,
        trigger = "always",
        arrow = false,
        variant = "overlay",
        children = {
            Lucy.Stack.new({
                direction = "horizontal",
                gap = "Space2",
                align = "center",
                children = {
                    Lucy.Text.new({ text = member.name, autoWidth = true }),
                    Lucy.Badge.new({ text = member.role, variant = "secondary" }),
                },
            }),
        },
    })
end

Lucy.Prompt.restyle(app, { variant = "overlay" })
```
