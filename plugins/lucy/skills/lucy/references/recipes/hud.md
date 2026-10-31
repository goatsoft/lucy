<!-- Made by scripts/skills.ts from docs/recipes/hud.md. Edit the doc, not this file. -->
# HUD

A HUD that shows over every screen: a level badge and coins in the top left,
and a health bar at the bottom. The coins pop when they change, the bar turns
red below a quarter, and a toast cheers each level up.

The server keeps coins and level as attributes on the player; the client copies
them into app state, and the HUD shows app state.

```luau [StarterPlayerScripts/Hud.client.luau]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local player = Players.LocalPlayer

local app = Lucy.App.new({
    toastPosition = "top-center", -- clear of the health bar
    state = {
        player = {
            coins = player:GetAttribute("Coins") or 0,
            level = player:GetAttribute("Level") or 1,
            health = 100,
            maxHealth = 100,
        },
    },
})

-- Game data into app state ------------------------------------------------

for _, name in { "Coins", "Level" } do
    player:GetAttributeChangedSignal(name):Connect(function()
        app.state:set(`player.{string.lower(name)}`, player:GetAttribute(name) or 0)
    end)
end

local function follow(character)
    local humanoid = character:WaitForChild("Humanoid")
    local function sync()
        app.state:batch(function()
            app.state:set("player.maxHealth", math.max(1, humanoid.MaxHealth))
            app.state:set("player.health", humanoid.Health)
        end)
    end
    sync()
    humanoid.HealthChanged:Connect(sync)
end
player.CharacterAdded:Connect(follow)
if player.Character then
    task.spawn(follow, player.Character)
end

-- A toast for each level up: a side effect, so a subscriber.
app.state:subscribe("player.level", function(new, old)
    if new > old then
        app.toast.success(`Level {new}!`)
    end
end)

-- The HUD --------------------------------------------------------------------

local coins = app.state:ref("player.coins")
local level = app.state:ref("player.level")
local health = app.state:ref("player.health")
local maxHealth = app.state:ref("player.maxHealth")

app.scenes:register("Hud", {
    layer = "overlay",
    ignoreGuiInset = false, -- below Roblox's top bar
    build = function(scene)
        scene.gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- clear of the notch

        local coinText = Lucy.Text.new({
            text = function()
                return tostring(coins())
            end,
            variant = "large",
            autoWidth = true,
        })

        -- Pop: push the spring's target up, then let it settle back. Springs jump
        -- when the player asks for reduced motion, so skip the pop then.
        local target = Lucy.ref(1)
        Lucy.new "UIScale" { Scale = Lucy.spring(target, 18, 0.5), Parent = coinText.Instance }
        Lucy.watch(coins, function()
            if Lucy.Preferences.reducedMotion() then
                return
            end
            target(1.35)
            task.delay(0.08, function()
                target(1)
            end)
        end)

        -- Top left
        Lucy.Stack.new({
            direction = "horizontal",
            gap = "Space2",
            align = "center",
            padding = "Space4",
            children = {
                Lucy.Badge.new({
                    text = function()
                        return `Lv {level()}`
                    end,
                }),
                Lucy.Icon.new({ icon = "lucide:coins", size = "lg", variant = "warning" }),
                coinText,
            },
            Parent = scene.gui,
        })

        -- Bottom centre: a Progress fills its parent's width, so give it a sized Stack.
        local bottom = Lucy.Stack.new({
            size = { mobile = UDim2.new(0.8, 0, 0, 14), default = UDim2.fromOffset(360, 14) },
            children = {
                Lucy.Progress.new({
                    value = health,
                    max = maxHealth,
                    height = 14,
                    variant = function()
                        return if health() / maxHealth() < 0.25 then "destructive" else "success"
                    end,
                }),
            },
            Parent = scene.gui,
        })
        bottom.Instance.AnchorPoint = Vector2.new(0.5, 1)
        bottom.Instance.Position = UDim2.new(0.5, 0, 1, -16)
    end,
})

app.scenes:show("Hud")
```

How it fits together:

- **Game data in, UI out.** Nothing in the HUD reads attributes or the
  Humanoid; it only reads app state. To test the HUD alone, set the state:
  `app.state:set("player.coins", 999)`.
- **Overlays** show over whatever screen is up, and take no focus; see
  [Show a HUD](../guide/scenes.md#show-a-hud).
- **Placing parts.** The top left Stack sits at the corner by default; the
  bottom one is moved with `AnchorPoint` and `Position`. See
  [Using a component](../components/index.md#using-a-component).
- **Sizes by device.** The bar's `size` is a responsive value: 80% of the width
  on a phone, 360 pixels elsewhere. See
  [Responsive values](../components/index.md#responsive-values).
- **Springs** are explained under [Animation](../reactivity.md#animation).
  With reduced motion on, springs jump instead of moving, which would turn the
  pop into a flicker, so the recipe skips it; see
  [Reduce motion](../reference/accessibility.md#reduce-motion).
- **Icons.** The coin icon needs your icon build; see [Icons](../../../lucy-icons/references/guide/icons.md).
