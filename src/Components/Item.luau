--!strict
--[[
	Item: a row in a list, with media, a title, a description and actions.

		Item.new({
			title = "Moonwalk",
			description = "Unlocked at level 5", -- hidden when empty
			media = icon,             -- an instance, handle or list, before the text
			actions = { buyButton },  -- instances or handles, after the text
			variant = "default",      -- default | outline | muted
			size = "md",              -- md | sm
			selected = false,
			disabled = false,
			onClick = function(item) end, -- makes the whole row clickable
			Parent = list,
		})

	State keys: title, description, variant, size, selected, disabled, visible.
	Parts: item.media, item.content, item.title, item.description, item.actions.
	With onClick the row is a button (item.Activated, item:click(), Component.clickable);
	without it, a plain frame. The text takes the width between media and actions.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Item = {}

Item.variants = { "default", "outline", "muted" }
Item.sizes = { "md", "sm" }

local ACTIVATED = Element.on("Activated")

local BASE, VARIANT, STATE, SELECTED, DISABLED = 0, 10, 20, 25, 30

Item.rules = {
	{
		selector = ".ui-item",
		priority = BASE,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, BorderSizePixel = 0 },
		transitions = { BackgroundTransparency = TweenInfo.new(0.12), BackgroundColor3 = TweenInfo.new(0.12) },
	},
	{ selector = ".ui-item::UICorner", priority = BASE, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-item::UIPadding",
		priority = BASE,
		properties = {
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
			PaddingTop = "$Space3",
			PaddingBottom = "$Space3",
		},
	},
	{
		selector = ".ui-item-size-sm::UIPadding",
		priority = VARIANT,
		properties = {
			PaddingLeft = "$Space3",
			PaddingRight = "$Space3",
			PaddingTop = "$Space2",
			PaddingBottom = "$Space2",
		},
	},
	{
		selector = ".ui-item-variant-outline::UIStroke",
		priority = VARIANT,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-item-variant-muted",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Muted", BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-item-clickable:Hover",
		priority = STATE,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-item-clickable:Press",
		priority = STATE,
		properties = { BackgroundColor3 = "$Muted", BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-item.ui-selected",
		priority = SELECTED,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-item.ui-selected::UIStroke",
		priority = SELECTED,
		properties = {
			Color = "$Ring",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-item-title",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-item-description",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-item-title.ui-disabled", priority = DISABLED, properties = { TextTransparency = 0.5 } },
	{
		selector = ".ui-item-description.ui-disabled",
		priority = DISABLED,
		properties = { TextTransparency = 0.5 },
	},
} :: { Component.Rule }

local function check(list: { string }, value: string, what: string)
	if not table.find(list, value) then
		error(`[Lucy] unknown Item {what} "{value}" (expected {table.concat(list, ", ")})`, 0)
	end
end

-- One tag list per variant and size pair, shared by every Item.
local tagLists: { [string]: { string } } = {}
local function variantTags(variant: string, size: string): { string }
	local key = variant .. "/" .. size
	local list = tagLists[key]
	if not list then
		list = { "ui-item-variant-" .. variant, "ui-item-size-" .. size }
		tagLists[key] = list
	end
	return list
end

local GAP = { md = "Space3", sm = "Space2" }

local function slot(name: string, order: number, items: any, horizontal: boolean): Frame
	local frame = Element.new("Frame", {
		Name = name,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = items ~= nil,
		if horizontal
			then Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			})
			else nil :: any,
	})
	Component.adopt(frame, items)
	return frame
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "item",
	defaults = {
		title = "",
		description = "",
		variant = "default",
		size = "md",
		selected = false,
		disabled = false,
		visible = true,
	},
	rules = Item.rules,
	render = function(h)
		local p: Component.Props = h.props
		check(Item.variants, h:get("variant"), "variant")
		check(Item.sizes, h:get("size"), "size")
		local app = h.app
		local variant, size, disabled = h:ref("variant"), h:ref("size"), h:ref("disabled")
		local description = h:ref("description")
		local clickable = p.onClick ~= nil

		local title = Element.new("TextLabel", {
			Name = "Title",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = h:ref("title"),
			Tags = { "ui-item-title" :: any, ["ui-disabled"] = disabled },
		})
		local body = Element.new("TextLabel", {
			Name = "Description",
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = description,
			Visible = function()
				return description() ~= ""
			end,
			Tags = { "ui-item-description" :: any, ["ui-disabled"] = disabled },
		})
		local content = Element.new("Frame", {
			Name = "Content",
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
			title,
			body,
		})
		h.title, h.description, h.content = title, body, content
		h.media = slot("Media", 1, p.media, false)
		h.actions = slot("Actions", 3, p.actions, true)

		local function enabled(): boolean
			return not disabled()
		end
		local props: { [any]: any } = {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			Tags = {
				(if clickable then "ui-item-clickable" else "ui-item-row") :: any,
				"ui-item",
				function()
					local v, s = variant(), size()
					check(Item.variants, v, "variant")
					check(Item.sizes, s, "size")
					return variantTags(v, s)
				end,
				["ui-selected"] = h:ref("selected"),
				["ui-disabled"] = disabled,
			},
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = function()
					return Component.space(app, GAP[size()] or GAP.md, 12)
				end,
			}),
			h.media,
			content,
			h.actions,
		}
		if clickable then
			props.Text = ""
			props.AutoButtonColor = false
			props.Interactable = enabled
			props.Selectable = enabled
			props[ACTIVATED] = function()
				h:click()
			end
		end
		return Element.new(if clickable then "TextButton" else "Frame", props)
	end,
}

function Item.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	if props and props.onClick ~= nil then
		Component.clickable(handle)
	end
	return handle
end

return Item
