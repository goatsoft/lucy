--!strict
--[[
	Pressable: a surface the player can click, tap or select with a gamepad that
	holds anything (an icon, a name, a price, a whole card).

		Pressable.new({
			children = { icon, Lucy.Text.new({ text = "Moonwalk" }) },
			selected = false,      -- shows as picked (tabs, filters, chosen cards)
			disabled = false,
			visible = true,
			size = UDim2.fromOffset(160, 200), -- fits its content when left out
			padding = "Space3",    -- a spacing token or pixels
			onClick = function(pressable) end,
			Parent = grid,
		})

	State keys: selected, disabled, visible.
	Events: pressable.Activated (Signal), pressable:click() (Component.clickable).
	It lays out nothing itself: put a Stack inside to arrange its content.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Pressable = {}

local ACTIVATED = Element.on("Activated")

local BASE, STATE, SELECTED, DISABLED = 0, 20, 25, 30

Pressable.rules = {
	{
		selector = ".ui-pressable",
		priority = BASE,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, BorderSizePixel = 0 },
		transitions = { BackgroundTransparency = TweenInfo.new(0.12), BackgroundColor3 = TweenInfo.new(0.12) },
	},
	{ selector = ".ui-pressable::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusMd" } },
	{ selector = ".ui-pressable:Hover", priority = STATE, properties = { BackgroundTransparency = 0 } },
	{
		selector = ".ui-pressable:Press",
		priority = STATE,
		properties = { BackgroundColor3 = "$Muted", BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-pressable.ui-selected",
		priority = SELECTED,
		properties = { BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-pressable.ui-selected::UIStroke",
		priority = SELECTED,
		properties = {
			Color = "$Ring",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-pressable.ui-disabled",
		priority = DISABLED,
		properties = { BackgroundTransparency = 1 },
	},
} :: { Component.Rule }

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "pressable",
	defaults = { selected = false, disabled = false, visible = true },
	rules = Pressable.rules,
	render = function(h)
		local p: Component.Props = h.props
		local disabled = h:ref("disabled")
		local function enabled(): boolean
			return not disabled()
		end
		local size: UDim2? = p.size
		local root = Element.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = size or UDim2.fromOffset(0, 0),
			AutomaticSize = if size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY,
			Visible = h:ref("visible"),
			Interactable = enabled,
			Selectable = enabled,
			Tags = { "ui-pressable" :: any, ["ui-selected"] = h:ref("selected"), ["ui-disabled"] = disabled },
			[ACTIVATED] = function()
				h:click()
			end,
		})
		if p.padding ~= nil then
			local pad = Component.space(h.app, p.padding, 0)
			Component.create("UIPadding", {
				PaddingTop = pad,
				PaddingBottom = pad,
				PaddingLeft = pad,
				PaddingRight = pad,
				Parent = root,
			})
		end
		Component.adopt(root, p.children)
		return root
	end,
}

function Pressable.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	Component.clickable(handle)
	return handle
end

return Pressable
