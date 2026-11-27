--!strict
--[[
	List: a vertical bulleted, numbered, chevron or plain list whose rows accept any
	Lucy Slot content (strings, Text, Icon, Badge, handles, instances or builders).

		Lucy.List.new({
			app = app,
			marker = "disc",   -- disc | decimal | chevron | none
			size = "md",       -- sm | md | lg
			gap = 4,
			items = {
				"Warm up on the dance floor",
				Lucy.Text.new({ text = "Hit a 10x combo", variant = "muted" }),
				{
					id = "tips",
					content = "Any rhythm tips?",
					variant = "primary",
					onClick = function() ... end,
				},
			},
			Parent = parent,
		})

	Items with `onClick` render as clickable rows (TextButton) with a hover highlight
	and gamepad focus; items without `onClick` render as static frames.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Slot = require(script.Parent.Slot)

export type ItemSpec = {
	id: string?,
	content: any,
	variant: string?,
	disabled: boolean?,
	marker: string?,
	onClick: (() -> ())?,
}

local List = {}

List.markers = { "disc", "decimal", "chevron", "none" }
List.sizes = { "sm", "md", "lg" }
List.variants = { "default", "primary", "destructive", "muted" }

local BASE, VARIANT, STATE, DISABLED = 0, 10, 20, 30

local itemRules: { Component.Rule } = {
	{
		selector = ".ui-list-item",
		priority = BASE,
		properties = {
			BackgroundColor3 = "$Accent",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextColor3 = "$Foreground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
		transitions = { BackgroundTransparency = TweenInfo.new(0.1) },
	},
	{
		selector = ".ui-list-item::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusSm" },
	},
	{
		selector = ".ui-list-item-clickable",
		priority = VARIANT,
		properties = {
			FontFace = "$FontSansMedium",
		},
	},
	{
		selector = ".ui-list-item-clickable:Hover",
		priority = STATE,
		properties = {
			BackgroundTransparency = 0.35,
		},
	},
	{
		selector = ".ui-list-item-clickable.ui-focus-visible",
		priority = STATE + 5,
		properties = {
			BackgroundColor3 = "$Accent",
			BackgroundTransparency = 0.2,
		},
	},
	{
		selector = ".ui-list-item-size-sm",
		priority = VARIANT,
		properties = { TextSize = "$TextXs" },
	},
	{
		selector = ".ui-list-item-size-lg",
		priority = VARIANT,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-list-item-variant-primary",
		priority = VARIANT,
		properties = { TextColor3 = "$Foreground", FontFace = "$FontSansSemibold" },
	},
	{
		selector = ".ui-list-item-variant-destructive",
		priority = VARIANT,
		properties = { TextColor3 = "$Destructive" },
	},
	{
		selector = ".ui-list-item-variant-muted",
		priority = VARIANT,
		properties = { TextColor3 = "$MutedForeground" },
	},
	{
		selector = ".ui-list-item-disabled",
		priority = DISABLED,
		properties = {
			TextColor3 = "$MutedForeground",
			TextTransparency = 0.45,
			BackgroundTransparency = 1,
		},
	},
	{
		selector = ".ui-list-item-disabled:Hover",
		priority = DISABLED,
		properties = { BackgroundTransparency = 1 },
	},
}

local markerRules: { Component.Rule } = {
	{
		selector = ".ui-list-marker",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-list-item-size-sm > .ui-list-marker",
		priority = VARIANT,
		properties = { TextSize = "$TextXs" },
	},
	{
		selector = ".ui-list-item-size-lg > .ui-list-marker",
		priority = VARIANT,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-list-item-variant-primary > .ui-list-marker",
		priority = VARIANT,
		properties = { TextColor3 = "$Foreground", FontFace = "$FontSansSemibold" },
	},
	{
		selector = ".ui-list-item-variant-destructive > .ui-list-marker",
		priority = VARIANT,
		properties = { TextColor3 = "$Destructive" },
	},
	{
		selector = ".ui-list-item-disabled > .ui-list-marker",
		priority = DISABLED,
		properties = {
			TextColor3 = "$MutedForeground",
			TextTransparency = 0.45,
		},
	},
}

local rules: { Component.Rule } = {}
for _, r in itemRules do
	table.insert(rules, r)
end
for _, r in Slot.flow(itemRules, " > .ui-list-content > .") do
	table.insert(rules, r)
end
for _, r in markerRules do
	table.insert(rules, r)
end
for _, r in Slot.rules do
	table.insert(rules, r)
end
List.rules = rules

local function isItemSpec(entry: any): boolean
	if type(entry) ~= "table" then
		return false
	end
	if typeof(entry.Instance) == "Instance" then
		return false
	end
	return entry.content ~= nil
		or entry.onClick ~= nil
		or entry.disabled ~= nil
		or entry.variant ~= nil
		or entry.marker ~= nil
end

local function markerText(kind: string, index: number, override: string?): string?
	if override ~= nil then
		return if #override > 0 then override else nil
	end
	if kind == "disc" then
		return "\226\128\162"
	elseif kind == "decimal" then
		return `{index}.`
	elseif kind == "chevron" then
		return ">"
	end
	return nil
end

local spec: Component.Spec = {
	kind = "list",
	rules = rules,
	defaults = {
		marker = "disc",
		size = "md",
	},
	render = function(h: Component.Handle)
		local props = h.props
		local app = h.app
		local sizeName = (props.size or "md") :: string
		local gap = if props.gap ~= nil then props.gap else 2

		local root = Element.new("Frame")({
			Name = props.id or "List",
			BackgroundTransparency = 1,
			Size = props.size2 or UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}) :: Frame
		if typeof(props.width) == "UDim" then
			root.Size = UDim2.new(props.width.Scale, props.width.Offset, 0, 0)
		end

		local listLayout = Instance.new("UIListLayout")
		listLayout.FillDirection = Enum.FillDirection.Vertical
		listLayout.Padding = UDim.new(0, gap)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = root

		local rowCleanups: { () -> () } = {}
		local function clearRows()
			for _, fn in rowCleanups do
				fn()
			end
			table.clear(rowCleanups)
		end
		h.maid:give(clearRows)

		Reactive.watchEffect(function()
			local items = Reactive.toValue(props.items)
			local markerKind = (Reactive.toValue(props.marker) or "disc") :: string
			Reactive.untrack(function()
				clearRows()
				if type(items) ~= "table" then
					return
				end
				for i, entry in items do
					local itemSpec: ItemSpec = if isItemSpec(entry)
						then entry :: ItemSpec
						else { content = entry }
					local clickable = type(itemSpec.onClick) == "function"
					local disabled = itemSpec.disabled == true
					local interactive = clickable and not disabled

					local row: GuiObject
					local conn: RBXScriptConnection? = nil
					if interactive then
						local btn = Instance.new("TextButton")
						btn.Text = ""
						btn.AutoButtonColor = false
						btn.Active = true
						btn.Selectable = true
						if app and app.selectionRing then
							btn.SelectionImageObject = app.selectionRing
						end
						btn:AddTag("ui-list-item-clickable")
						local cb = itemSpec.onClick
						if cb then
							conn = btn.Activated:Connect(cb)
						end
						row = btn
					else
						local frame = Instance.new("Frame")
						frame.Active = false
						frame.Selectable = false
						row = frame
					end

					row.Name = itemSpec.id or `Item{i}`
					row.Size = UDim2.fromScale(1, 0)
					row.AutomaticSize = Enum.AutomaticSize.Y
					row.LayoutOrder = i
					row:AddTag("ui-list-item")
					if sizeName ~= "md" then
						row:AddTag(`ui-list-item-size-{sizeName}`)
					end
					if disabled then
						row:AddTag("ui-list-item-disabled")
					elseif itemSpec.variant and itemSpec.variant ~= "default" then
						row:AddTag(`ui-list-item-variant-{itemSpec.variant}`)
					end

					local pad = Instance.new("UIPadding")
					local padded = clickable or disabled
					pad.PaddingLeft = UDim.new(0, if padded then 8 else 2)
					pad.PaddingRight = UDim.new(0, if padded then 8 else 2)
					pad.PaddingTop = UDim.new(0, if padded then 5 else 2)
					pad.PaddingBottom = UDim.new(0, if padded then 5 else 2)
					pad.Parent = row

					local rowLayout = Instance.new("UIListLayout")
					rowLayout.FillDirection = Enum.FillDirection.Horizontal
					rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
					rowLayout.Padding = UDim.new(0, 8)
					rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
					rowLayout.Parent = row

					local glyph = markerText(markerKind, i, itemSpec.marker)
					if glyph then
						local markerLabel = Instance.new("TextLabel")
						markerLabel.Name = "Marker"
						markerLabel.Text = glyph
						markerLabel.AutomaticSize = Enum.AutomaticSize.XY
						markerLabel.Size = UDim2.fromOffset(0, 0)
						markerLabel.LayoutOrder = 1
						markerLabel:AddTag("ui-list-marker")
						markerLabel.Parent = row
					end

					local contentBox = Instance.new("Frame")
					contentBox.Name = "Content"
					contentBox.BackgroundTransparency = 1
					contentBox.Size = UDim2.fromOffset(0, 0)
					contentBox.AutomaticSize = Enum.AutomaticSize.XY
					contentBox.LayoutOrder = 2
					contentBox:AddTag("ui-list-content")
					local contentLayout = Instance.new("UIListLayout")
					contentLayout.FillDirection = Enum.FillDirection.Horizontal
					contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
					contentLayout.Padding = UDim.new(0, 8)
					contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
					contentLayout.Parent = contentBox
					contentBox.Parent = row

					Slot.fill(contentBox, itemSpec.content, { app = app })
					row.Parent = root

					table.insert(rowCleanups, function()
						if conn then
							conn:Disconnect()
						end
						row:Destroy()
					end)
				end
			end)
		end)

		if props.Parent then
			root.Parent = props.Parent
		end

		h.Instance = root
		return root
	end,
}

Component.define(spec)

function List.new(props: { [string]: any }): any
	return Component.mount(spec, props)
end

return List
