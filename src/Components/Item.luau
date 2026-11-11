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
			children = { swatches },  -- optional slot under the text (Slot: strings, handles,
			                          -- instances, builders)
			focus = "controls",       -- controls | tile (not a state key)
			onClick = function(item) end, -- makes the whole row clickable
			Parent = list,
		})
		item:enter()  item:leave()   -- a tile: step in onto its first control, step back out

	State keys: title, description, variant, size, selected, disabled, visible, entered.
	Parts: item.media, item.content, item.title, item.description, item.actions.
	With onClick the row is a button (item.Activated, item:click(), Component.clickable);
	without it, a plain frame. The text takes the width between media and actions.

	focus = "tile" (Core/Tiles): the whole row is one stop for a gamepad and the keys, its
	controls (actions, children) wait inside it. A, Enter, or left or right on it steps in
	(entered): the D-pad and keys then stay on its controls, A presses one, B steps back out
	onto the row. A tile is always a button; onClick, if given, runs on a click or tap, A steps
	in. The mouse and touch reach its controls directly.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Tiles = require(script.Parent.Parent.Core.Tiles)
local Slot = require(script.Parent.Slot)

local Item = {}

Item.variants = { "default", "outline", "muted" }
Item.sizes = { "md", "sm" }
Item.focuses = { "controls", "tile" }

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
	-- A tile the player is inside: ringed, so it reads as the place the D-pad is in
	{
		selector = ".ui-item.ui-tile-open::UIStroke",
		priority = SELECTED + 1,
		properties = {
			Color = "$Ring",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
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
		entered = false,
	},
	rules = Item.rules,
	render = function(h)
		local p: Component.Props = h.props
		check(Item.variants, h:get("variant"), "variant")
		check(Item.sizes, h:get("size"), "size")
		check(Item.focuses, p.focus or "controls", "focus")
		local app = h.app
		local variant, size, disabled = h:ref("variant"), h:ref("size"), h:ref("disabled")
		local description = h:ref("description")
		local clickable = p.onClick ~= nil
		local tile = p.focus == "tile"
		local entered = h:ref("entered")

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
		-- The slot under the text (a row of colours, a progress bar)
		Slot.fill(content, p.children, { app = app, startOrder = 3 })
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
				[Tiles.TAG] = tile,
				[Tiles.OPEN] = entered,
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
		if clickable or tile then
			props.Text = ""
			props.AutoButtonColor = false
			props.Interactable = enabled
			props.Selectable = function(): boolean
				-- An open tile is not a stop itself: its controls are
				return enabled() and not entered()
			end
			if tile then
				-- Open, the gamepad stays inside (the engine's own trap, as a modal Dialog's)
				local function edge(): Enum.SelectionBehavior
					return if entered() then Enum.SelectionBehavior.Stop else Enum.SelectionBehavior.Escape
				end
				props.SelectionGroup = entered
				props.SelectionBehaviorUp = edge
				props.SelectionBehaviorDown = edge
				props.SelectionBehaviorLeft = edge
				props.SelectionBehaviorRight = edge
			end
			props[ACTIVATED] = function()
				h:click()
			end
		end
		return Element.new(if clickable or tile then "TextButton" else "Frame", props)
	end,
}

-- A tile's way in and out (Core/Tiles): entered, its own focus scope and back handler
local function tiled(handle: any)
	local popScope: (() -> ())? = nil
	local popBack: (() -> ())? = nil

	-- Steps in, onto `target` (a control inside it) or its first control
	function handle.enter(h, target: GuiObject?)
		if h.destroyed or h:get("entered") or h:get("disabled") then
			return
		end
		local input = h.app.input
		local first = target or input:selectables(h.Instance)[1]
		if not first then
			return -- nothing inside to step onto
		end
		h:set("entered", true)
		Tiles.opened(input, h)
		popBack = input:pushBack(function(): boolean
			h:leave()
			return true
		end)
		popScope = input:pushScope({ root = h.Instance, defaultFocus = first, returnFocus = h.Instance })
		if input:focused() ~= first then
			input:focus(first)
		end
	end

	-- Steps back out: focus goes to the tile if it was inside
	function handle.leave(h)
		if not h:get("entered") then
			return
		end
		h:set("entered", false)
		Tiles.closed(h.app.input, h)
		local back, scope = popBack, popScope
		popBack, popScope = nil, nil
		if back then
			back()
		end
		if scope then
			scope()
		end
	end

	-- A click or tap runs onClick; A or Enter while navigating steps in
	local click = handle.click
	function handle.click(h)
		if h.app.input:isNavigating() and not h:get("entered") then
			h:enter()
			return
		end
		click(h)
	end

	handle.maid:give(function()
		handle:leave()
	end)
end

function Item.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	local tile = props ~= nil and props.focus == "tile"
	if tile or (props and props.onClick ~= nil) then
		Component.clickable(handle)
	end
	if tile then
		tiled(handle)
	end
	return handle
end

return Item
