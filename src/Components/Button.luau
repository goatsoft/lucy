--[[
	Button (shadcn: Button)

		Button.new({
			text = "Play",
			variant = "default",   -- default | destructive | outline | secondary | ghost | link
			size = "md",           -- sm | md | lg | icon
			disabled = false,
			visible = true,
			onClick = function(button) end,
			id = "play",           -- state lives at ui.play
			Parent = frame,
		})

	State keys: text, variant, size, disabled, visible.
	Events: button.Activated (Signal). button:click() runs the click path in code/tests.

	Visuals live in Button.rules (Universal Styling); code only sets behaviour and
	layout so a rule is never overridden by an instance property.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Signal = require(script.Parent.Parent.Core.Signal)

local Button = {}

Button.variants = { "default", "destructive", "outline", "secondary", "ghost", "link" }
Button.sizes = { "sm", "md", "lg", "icon" }

local BASE, VARIANT, STATE, DISABLED = 0, 10, 20, 30

Button.rules = {
	{
		selector = ".ui-button",
		priority = BASE,
		properties = {
			BackgroundColor3 = "$Primary",
			TextColor3 = "$PrimaryForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
			BorderSizePixel = 0,
			Size = "$ControlMd",
		},
		transitions = { BackgroundColor3 = TweenInfo.new(0.12) },
	},
	{ selector = ".ui-button::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-button::UIPadding",
		priority = BASE,
		properties = { PaddingLeft = "$Space4", PaddingRight = "$Space4" },
	},

	-- Variants
	{ selector = ".ui-button-variant-default:Hover", priority = STATE, properties = { BackgroundColor3 = "$PrimaryHover" } },
	{
		selector = ".ui-button-variant-destructive",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Destructive", TextColor3 = "$DestructiveForeground" },
	},
	{
		selector = ".ui-button-variant-destructive:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$DestructiveHover" },
	},
	{
		selector = ".ui-button-variant-outline",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Background", TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-button-variant-outline::UIStroke",
		priority = VARIANT,
		properties = { Color = "$Input", Thickness = "$StrokeThin", ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
	},
	{
		selector = ".ui-button-variant-outline:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$Accent", TextColor3 = "$AccentForeground" },
	},
	{
		selector = ".ui-button-variant-secondary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Secondary", TextColor3 = "$SecondaryForeground" },
	},
	{
		selector = ".ui-button-variant-secondary:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$SecondaryHover" },
	},
	{
		selector = ".ui-button-variant-ghost",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, TextColor3 = "$Foreground" },
	},
	{
		selector = ".ui-button-variant-ghost:Hover",
		priority = STATE,
		properties = { BackgroundTransparency = 0, TextColor3 = "$AccentForeground" },
	},
	{
		selector = ".ui-button-variant-link",
		priority = VARIANT,
		properties = { BackgroundTransparency = 1, TextColor3 = "$Primary" },
	},
	{
		selector = ".ui-button-variant-link:Hover",
		priority = STATE,
		properties = { TextColor3 = "$MutedForeground" },
	},

	-- Sizes
	{ selector = ".ui-button-size-sm", priority = VARIANT, properties = { Size = "$ControlSm", TextSize = "$TextXs" } },
	{
		selector = ".ui-button-size-sm::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space3", PaddingRight = "$Space3" },
	},
	{ selector = ".ui-button-size-lg", priority = VARIANT, properties = { Size = "$ControlLg", TextSize = "$TextBase" } },
	{
		selector = ".ui-button-size-lg::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space6", PaddingRight = "$Space6" },
	},
	{ selector = ".ui-button-size-icon", priority = VARIANT, properties = { Size = "$ControlIcon", TextSize = "$TextBase" } },
	{
		selector = ".ui-button-size-icon::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space0", PaddingRight = "$Space0" },
	},

	-- Disabled (the component also sets Interactable = false)
	{ selector = ".ui-button.ui-disabled", priority = DISABLED, properties = { TextTransparency = 0.5 } },
}
-- Solid variants fade their background when disabled; transparent ones stay transparent.
for _, variant in { "default", "destructive", "outline", "secondary" } do
	table.insert(Button.rules, {
		selector = `.ui-button-variant-{variant}.ui-disabled`,
		priority = DISABLED,
		properties = { BackgroundTransparency = 0.5 },
	})
end

local function check(list: { string }, value: string, what: string)
	if not table.find(list, value) then
		error(`[Lucy] unknown Button {what} "{value}" (expected {table.concat(list, ", ")})`, 4)
	end
end

function Button.new(props: { [string]: any }?)
	local p = props or {}
	local activated = Signal.new()

	local handle = Component.mount({
		kind = "button",
		props = p,
		defaults = { text = "Button", variant = "default", size = "md", disabled = false, visible = true },
		rules = Button.rules,
		render = function(h)
			local button = Component.create("TextButton", {
				AutoButtonColor = false,
				Tags = { "ui-button" },
			})
			h.maid:give(button.Activated:Connect(function()
				h:click()
			end))
			return button
		end,
		update = function(h, state)
			check(Button.variants, state.variant, "variant")
			check(Button.sizes, state.size, "size")
			local button = h.Instance
			button.Text = state.text
			button.Visible = state.visible
			button.Interactable = not state.disabled
			button.Selectable = not state.disabled
			button.AutomaticSize = if state.size == "icon" then Enum.AutomaticSize.None else Enum.AutomaticSize.X
			Component.setVariant(button, "ui-button", "variant", state.variant)
			Component.setVariant(button, "ui-button", "size", state.size)
			Component.setFlag(button, "ui-disabled", state.disabled)
		end,
	})

	handle.Activated = activated
	handle.maid:give(function()
		activated:DisconnectAll()
	end)

	local lastClick = -math.huge
	function handle.click(h)
		if h.destroyed or h:get("disabled") then
			return
		end
		-- Keyboard Enter can reach us twice (engine activation + InputManager); keep one.
		local now = os.clock()
		if now - lastClick < 0.05 then
			return
		end
		lastClick = now
		if p.onClick then
			p.onClick(h)
		end
		activated:Fire(h)
	end

	return handle
end

return Button
