<!-- Made by scripts/skills.ts from docs/recipes/shop.md. Edit the doc, not this file. -->
# Shop

The Emote Shop in a dialog: a grid of dance cards, each with a Buy button that
greys out when the player can't afford it. Buying asks first, then takes the coins and
shows a toast. B on a keyboard, X on a gamepad and a HUD button open and close
it, and the character stops while it is open.

```luau [StarterPlayerScripts/Shop.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local app = Lucy.App.new({
    state = { player = { coins = 500 } },
})

local ITEMS = {
    { name = "Moonwalk", price = 300, icon = "lucide-extended:sparkles-filled" },
    { name = "Robot", price = 120, icon = "lucide-extended:star-filled" },
    { name = "Shuffle", price = 90, icon = "lucide-extended:flame-filled" },
    { name = "Twirl", price = 60, icon = "lucide-extended:zap-filled" },
    { name = "Wave", price = 25, icon = "lucide-extended:heart-filled" },
    { name = "Groove", price = 500, icon = "lucide-extended:party-popper-filled" },
}

local coins = app.state:ref("player.coins")

local function buy(item)
    Lucy.Dialog.alert({
        title = `Buy {item.name}?`,
        description = `The {item.name} emote costs {item.price} coins.`,
        confirmText = "Buy",
        onConfirm = function()
            -- In a real game, ask the server to buy and let it change the coins.
            if coins() < item.price then
                app.toast.error("Not enough coins")
                return
            end
            coins(coins() - item.price)
            app.toast.success(`{item.name} unlocked`, { description = `-{item.price} coins` })
        end,
    })
end

local cards = {}
for _, item in ITEMS do
    table.insert(cards, Lucy.Panel.new({
        title = item.name,
        children = {
            Lucy.Stack.new({
                direction = "horizontal",
                gap = "Space2",
                align = "center",
                children = {
                    Lucy.Icon.new({ icon = item.icon, size = "lg" }),
                    Lucy.Text.new({ text = `{item.price} coins`, variant = "muted", autoWidth = true }),
                },
            }),
        },
        footer = {
            Lucy.Button.new({
                text = "Buy",
                disabled = function()
                    return coins() < item.price
                end,
                onClick = function()
                    buy(item)
                end,
            }),
        },
    }))
end

local shop = Lucy.Dialog.new({
    title = "Emote Shop",
    size = "lg",
    maxHeight = 520,
    children = {
        Lucy.Text.new({
            text = function()
                return `Coins: {coins()}`
            end,
            variant = "large",
        }),
        Lucy.Grid.new({
            columns = { mobile = 2, default = 3 },
            cellHeight = 190,
            gap = "Space3",
            children = cards,
        }),
    },
})

-- The hotkey, in a set of menu keys apart from gameplay.
app.actions:define("menus", {
    shop = { Enum.KeyCode.B, Enum.KeyCode.ButtonX },
})
app.actions:on("shop", function()
    shop:toggle()
end)

-- A HUD button, for mouse and touch players, showing the key for the others.
app.scenes:register("ShopButton", {
    layer = "overlay",
    build = function(scene)
        local button = Lucy.Button.new({
            icon = "lucide-extended:shopping-bag-filled",
            text = "Emote Shop",
            hint = { keyboard = Enum.KeyCode.B, gamepad = Enum.KeyCode.ButtonX },
            onClick = function()
                shop:toggle()
            end,
            Parent = scene.gui,
        })
        button.Instance.AnchorPoint = Vector2.new(1, 1)
        button.Instance.Position = UDim2.new(1, -16, 1, -16)
    end,
})
app.scenes:show("ShopButton")

-- The character stops while the shop, or the confirm on top of it, is open.
Lucy.effectScope():run(function()
    Lucy.useWhile(function()
        return app:modalOpen()
    end, function()
        return app.actions:disable("movement")
    end)
end)
```

How it fits together:

- **Buy greys out** because `disabled` is a getter that reads the coins; it
  updates by itself when they change. See
  [Reactive props](../components/index.md#reactive-props).
- **The confirm** is an alert: it opens on top of the shop, and back (B or
  Backspace) picks Cancel. See [Alert dialogs](../components/dialog.md#alert-dialogs).
- **The grid** has 2 columns on a phone and 3 elsewhere; the dialog's body
  scrolls when the dances don't fit, so the grid needs no scroll of its own.
- **The hotkey** still fires while the confirm is open, so pressing B there
  closes the shop under it. To stop that, see
  [While a menu is open](../guide/actions.md#while-a-menu-is-open).
- **The coins** change on the client here, to keep the recipe short. In a game,
  the server owns them: send a buy request, check it on the server, and set the
  new total from there.
- **Icons** need your icon build; see [Icons](../../../lucy-icons/references/guide/icons.md). Until then the
  emote icons are blank and the HUD button shows its text.
