<!-- Made by scripts/skills.ts from docs/recipes/hud.md. Edit the doc, not this file. -->
# HUD

A dance floor HUD that shows over every screen: a combo badge and coins in the
top left, and a hype meter at the bottom. The coins pop when they change, the
meter turns from amber to green once the crowd is hyped, and a toast cheers
every 10 combo.

The server keeps coins, hype and combo as attributes on the player; the client
copies them into app state, and the HUD shows app state.

```luau [StarterPlayerScripts/Hud.client.luau]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local player = Players.LocalPlayer

local app = Lucy.App.new({
    toastPosition = "top-center", -- clear of the hype meter
    state = {
        player = {
            coins = player:GetAttribute("Coins") or 0,
            hype = player:GetAttribute("Hype") or 0, -- 0 to 100
            combo = player:GetAttribute("Combo") or 0,
        },
    },
})

-- Game data into app state ------------------------------------------------

for _, name in { "Coins", "Hype", "Combo" } do
    player:GetAttributeChangedSignal(name):Connect(function()
        app.state:set(`player.{string.lower(name)}`, player:GetAttribute(name) or 0)
    end)
end

-- A toast every 10 combo: a side effect, so a subscriber.
app.state:subscribe("player.combo", function(new, old)
    if new > old and new // 10 > old // 10 then
        app.toast.success(`x{new} combo!`)
    end
end)

-- The HUD --------------------------------------------------------------------

local coins = app.state:ref("player.coins")
local hype = app.state:ref("player.hype")
local combo = app.state:ref("player.combo")

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
                        return `x{combo()} combo`
                    end,
                }),
                Lucy.Icon.new({ icon = "lucide-extended:coins-duotone", size = "lg", variant = "warning" }),
                coinText,
            },
            Parent = scene.gui,
        })

        -- Bottom centre: a Progress fills its parent's width, so give it a sized Stack.
        local bottom = Lucy.Stack.new({
            size = { mobile = UDim2.new(0.8, 0, 0, 14), default = UDim2.fromOffset(360, 14) },
            children = {
                Lucy.Progress.new({
                    value = hype,
                    max = 100,
                    height = 14,
                    variant = function()
                        return if hype() < 50 then "warning" else "success"
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

- **Game data in, UI out.** Nothing in the HUD reads attributes; it only reads
  app state. To test the HUD alone, set the state:
  `app.state:set("player.coins", 999)`.
- **Overlays** show over whatever screen is up, and take no focus; see
  [Show a HUD](../guide/scenes.md#show-a-hud).
- **Placing parts.** The top left Stack sits at the corner by default; the
  bottom one is moved with `AnchorPoint` and `Position`. See
  [Using a component](../components/index.md#using-a-component).
- **Sizes by device.** The meter's `size` is a responsive value: 80% of the
  width on a phone, 360 pixels elsewhere. See
  [Responsive values](../components/index.md#responsive-values).
- **Springs** are explained under [Animation](../reactivity.md#animation).
  With reduced motion on, springs jump instead of moving, which would turn the
  pop into a flicker, so the recipe skips it; see
  [Reduce motion](../reference/accessibility.md#reduce-motion).
- **Icons.** The coin icon needs your icon build; see [Icons](../../../lucy-icons/references/guide/icons.md).
