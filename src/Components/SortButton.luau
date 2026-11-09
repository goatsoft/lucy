--!strict
--[[
	SortButton: a column heading that sorts a list when pressed, as a table's
	header does. DataGrid's headers are SortButtons; use them on their own over
	a grid of cards or any list sorted with Lucy.useSort.

		local dances = Lucy.useSort({ data = owned, columns = columns, multi = true })
		SortButton.new({
			sort = dances,          -- a useSort or useTable result
			column = "rarity",      -- the column id it sorts
			text = "Rarity",        -- the label; the column's header by default ("" for none)
			children = { ... },     -- optional: after the label in its slot (Slot: strings, handles,
			                        -- instances, builders), before the chevron
			align = "left",         -- left | center | right
			disabled = false,       -- on its own for a column that does not sort
			onClick = function(button) end,  -- after it sorts
			size = UDim2,           -- as wide as its text (padded either side) and ControlSm tall by default
		})

	Each press goes the column's first direction, the other, then off (see
	useSort). While it sorts, the label is bright and a chevron shows the
	direction; while more than one column sorts, a small number shows its
	place (1 leads, 2 breaks its ties, and so on).

	A sort button is a box with a slot (ADR 0042): its label and children take its colours,
	muted until it sorts (Slot.flow).

	button.label, button.icon (an Icon), button.priority (the number's label).
	State keys: disabled, visible. Events: "activate", for Lucy.useUiSound.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Slot = require(script.Parent.Slot)

local SortButton = {}

local ACTIVATED = Element.on("Activated")
local ALIGN = {
	left = Enum.HorizontalAlignment.Left,
	center = Enum.HorizontalAlignment.Center,
	right = Enum.HorizontalAlignment.Right,
}

local rules: { Component.Rule } = {
	{
		selector = ".ui-sort-button",
		priority = 0,
		properties = {
			BackgroundColor3 = "$Accent",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-sort-button::UICorner", priority = 0, properties = { CornerRadius = "$RadiusSm" } },
	-- Sized to its words (no size: over a grid of cards), it pads its sides, so its hover fill
	-- clears the text; as a table's header (a size) it keeps none, lined up with its column
	{
		selector = ".ui-sort-button.ui-sort-hug::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space2", PaddingRight = "$Space2" },
	},
	{ selector = ".ui-sort-button:Hover", priority = 10, properties = { BackgroundTransparency = 0 } },
	{ selector = ".ui-sort-button.ui-sorted", priority = 10, properties = { TextColor3 = "$Foreground" } },
	{
		selector = ".ui-sort-priority",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSansSemibold",
			TextSize = "$TextXs",
		},
	},
}
-- The label and the slot's children take the button's colours (ADR 0042); the chevron and the
-- number stay muted, over the twins
SortButton.rules = table.clone(rules)
for _, rule in Slot.flow(rules) do
	table.insert(SortButton.rules, rule)
end
table.insert(SortButton.rules, {
	selector = ".ui-sort-button > .ui-sort-chevron",
	priority = 50,
	properties = { ImageColor3 = "$MutedForeground" },
})
table.insert(SortButton.rules, {
	selector = ".ui-sort-button > .ui-sort-priority",
	priority = 50,
	properties = { TextColor3 = "$MutedForeground" },
})
for _, rule in Slot.rules do
	table.insert(SortButton.rules, rule)
end

local spec: Component.Spec = {
	kind = "sort-button",
	defaults = { disabled = false, visible = true },
	rules = SortButton.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local sort = p.sort
		local columnId: string = p.column
		local header: any = nil
		for _, column in sort.columns do
			if column.id == columnId then
				header = column.header
			end
		end
		local disabled = h:ref("disabled")
		local function enabled(): boolean
			return not disabled()
		end
		local function direction(): string | false
			return sort.sortedBy(columnId)
		end
		local height = Composables.useMetric(app, "ControlSm")

		local labelText: string = if p.text ~= nil
			then tostring(p.text)
			elseif p.children ~= nil then ""
			elseif header ~= nil then tostring(header)
			else columnId
		local label = Element.new("TextLabel", {
			Name = "Label",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Text = labelText,
			Visible = labelText ~= "",
			Tags = { "ui-sort-label", Slot.TEXT_TAG },
		})
		local icon = Icon.new({
			app = app,
			icon = function(): string
				return if direction() == "desc" then "lucy:chevron-down" else "lucy:chevron-up"
			end,
			size = "sm",
			variant = "muted",
			name = "SortIcon",
			layoutOrder = 1000,
			visible = function(): boolean
				return direction() ~= false
			end,
		})
		icon.Instance:AddTag("ui-sort-chevron")
		local priority = Element.new("TextLabel", {
			Name = "Priority",
			LayoutOrder = 1001,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Text = function(): string
				return tostring(sort.priority(columnId) or "")
			end,
			Visible = function(): boolean
				return direction() ~= false and #sort.list() > 1
			end,
			Tags = { "ui-sort-priority" },
		})
		h.label = label
		h.icon = icon
		h.priority = priority

		local root = Element.new("TextButton", {
			Name = "Sort",
			Text = "",
			AutoButtonColor = false,
			AutomaticSize = if p.size then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			Size = p.size or function(): UDim2
				return UDim2.fromOffset(0, height())
			end,
			Visible = h:ref("visible"),
			Interactable = enabled,
			Selectable = enabled,
			Tags = {
				"ui-sort-button" :: any,
				["ui-sorted"] = function(): boolean
					return direction() ~= false
				end,
				["ui-sort-hug"] = p.size == nil,
				["ui-disabled"] = disabled,
			},
			[ACTIVATED] = function()
				h:click()
			end,
			Element.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = ALIGN[p.align or "left"] or Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			label,
			icon.Instance,
			priority,
		})
		-- The slot's children after the label, before the chevron
		Slot.fill(root, p.children, { app = app, startOrder = 1 })
		return root
	end,
}

function SortButton.new(props: Component.Props?): Component.Handle
	local given: Component.Props = props or {}
	assert(given.sort, "[Lucy] SortButton needs sort (a useSort or useTable result)")
	assert(type(given.column) == "string", "[Lucy] SortButton needs column (a column id)")
	local p = table.clone(given)
	if not given.sort.canSort(given.column) then
		p.disabled = true
	end
	-- Sort first, then the game's own onClick sees the new order.
	local onClick = given.onClick
	p.onClick = function(h)
		given.sort.toggle(given.column)
		if onClick then
			onClick(h)
		end
	end
	local handle = Component.mount(spec, p)
	Component.clickable(handle)
	return handle
end

return SortButton
