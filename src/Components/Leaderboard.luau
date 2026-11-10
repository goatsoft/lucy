--!strict
--[[
	Leaderboard: ranked players, best first, each with their rank, headshot, name and value.
	The top three wear the medal colours (and the game's medal icons, if given), the player's own
	row is lit, and when they are not in the list their row is pinned under it.

		Leaderboard.new({
			rows = entries,            -- { { userId, name, value, rank? } }, best first; an array,
			                           -- a ref or a getter. rank defaults to the row's place
			own = mine,                -- the player's entry (or nil): lit when listed, else pinned
			unranked = "100+",         -- the pinned rank when own.rank is nil
			format = function(value) return `{value} PTS` end, -- default: 14,850
			medals = { "set:queen", "set:crown", "set:crown" }, -- icons for 1st to 3rd, in place
			                           -- of the number; false for no medal colours at all
			loading = false,           -- skeleton rows in place of the list
			placeholders = 5,          -- how many skeleton rows
			empty = "No one yet",      -- shown with no rows
			size = "md",               -- sm | md | lg
			avatars = true,            -- the headshots (players with no userId get a monogram)
		})

	The value is a number (formatted) or text. Rows are keyed by userId (or name), so new data
	updates rows in place and moves them. Colours come from style rules: $MedalGold,
	$MedalSilver, $MedalBronze for the top three, $Accent and $Ring for the player's row.

	Parts: board.list, board.pinned (the own row's frame, with a separator above),
	board.skeletons, board.emptyLabel, board.rowFor(id), board.rankLabelFor(id),
	board.medalFor(id), board.nameLabelFor(id), board.valueLabelFor(id), board.rowCount(),
	board.ownRankLabel, board.ownNameLabel, board.ownValueLabel.

	State keys: size, visible.
]]

local Avatar = require(script.Parent.Avatar)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Skeleton = require(script.Parent.Skeleton)

local Leaderboard = {}

Leaderboard.sizes = { "sm", "md", "lg" }
Leaderboard.MEDALS = { "gold", "silver", "bronze" }

-- Per size: the rank column's width (pixels), the avatar's size, the gap and row padding tokens
local RANK_WIDTH = { sm = 32, md = 40, lg = 56 }
local AVATAR = { sm = "sm", md = "md", lg = "lg" }
local ICON = { sm = "sm", md = "md", lg = "lg" }
local GAP = { sm = 8, md = 12, lg = 16 }
local SKELETON_HEIGHT = { sm = 40, md = 52, lg = 72 }

local BASE, SIZE, OWN, MEDAL = 0, 10, 20, 50

local rules: { Component.Rule } = {
	{
		selector = ".ui-leaderboard-row",
		priority = BASE,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-leaderboard-row::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusMd" },
	},
	{
		selector = ".ui-leaderboard-row::UIPadding",
		priority = BASE,
		properties = {
			PaddingLeft = "$Space2",
			PaddingRight = "$Space3",
			PaddingTop = "$Space2",
			PaddingBottom = "$Space2",
		},
	},
	{
		selector = ".ui-leaderboard-row-own",
		priority = OWN,
		properties = { BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-leaderboard-row-own::UIStroke",
		priority = OWN,
		properties = {
			Color = "$Ring",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	-- The lit row is the avatar's own colour, so its circle stands on the background's
	{
		selector = ".ui-leaderboard-row-own > .ui-avatar",
		priority = OWN,
		properties = { BackgroundColor3 = "$Background" },
	},
	{
		selector = ".ui-leaderboard-rank",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSansBold",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-leaderboard-name",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-leaderboard-value",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansBold",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-leaderboard-size-md.ui-leaderboard-text",
		priority = SIZE,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-leaderboard-size-lg.ui-leaderboard-text",
		priority = SIZE,
		properties = { TextSize = "$TextXl" },
	},
	{
		selector = ".ui-leaderboard-empty",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-leaderboard-divider", priority = BASE, properties = { BackgroundColor3 = "$Border" } },
}
-- The medal colours on the rank, its icon and the value
for _, medal in Leaderboard.MEDALS do
	local token = `$Medal{string.upper(medal:sub(1, 1))}{medal:sub(2)}`
	table.insert(rules, {
		selector = `.ui-leaderboard-tint.ui-leaderboard-medal-{medal}`,
		priority = MEDAL,
		properties = { TextColor3 = token },
	})
	table.insert(rules, {
		selector = `.ui-leaderboard-medal-icon.ui-leaderboard-medal-{medal}`,
		priority = MEDAL,
		properties = { ImageColor3 = token },
	})
end
Leaderboard.rules = rules

local function check(size: string)
	if not table.find(Leaderboard.sizes, size) then
		error(
			`[Lucy] unknown Leaderboard size "{size}" (expected {table.concat(Leaderboard.sizes, ", ")})`,
			0
		)
	end
end

-- 14850 -> "14,850"
function Leaderboard.formatNumber(n: number): string
	local whole = tostring(math.floor(math.abs(n)))
	local grouped = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return if n < 0 then "-" .. grouped else grouped
end

local function idOf(row: any, index: number): any
	return row.userId or row.name or index
end

local spec: Component.Spec = {
	kind = "leaderboard",
	defaults = { size = "md", visible = true },
	rules = Leaderboard.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		check(h:get("size"))
		local size = h:ref("size")
		local function sizeNow(): string
			local s = size()
			check(s)
			return s
		end
		local function rows(): { any }
			return Reactive.toValue(p.rows) or {}
		end
		local function own(): any?
			return Reactive.toValue(p.own)
		end
		local function loading(): boolean
			return Reactive.toValue(p.loading) == true
		end
		local medalIcons: { string }? = if type(p.medals) == "table" then p.medals else nil
		local useMedals = p.medals ~= false
		local avatars = p.avatars ~= false
		local format = p.format
		local function valueText(value: any): string
			if value == nil then
				return ""
			elseif format then
				return tostring(format(value))
			elseif type(value) == "number" then
				return Leaderboard.formatNumber(value)
			end
			return tostring(value)
		end
		local function medalOf(rank: number?): string?
			return if useMedals and rank then Leaderboard.MEDALS[rank] else nil
		end
		local function sizeTag(): string
			return `ui-leaderboard-size-{sizeNow()}`
		end

		-- One row's look, from getters of its rank, entry and whether it is the player's
		local function buildRow(
			name: string,
			rank: () -> number?,
			rankText: () -> string,
			entry: () -> any?,
			lit: () -> boolean
		)
			local function medalTag(): string?
				local medal = medalOf(rank())
				return if medal then `ui-leaderboard-medal-{medal}` else nil
			end
			local function medalIcon(): string
				local r = rank()
				return if medalIcons and r and medalIcons[r] then medalIcons[r] else ""
			end
			local rankLabel = Element.new("TextLabel", {
				Name = "Rank",
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextScaled = false,
				Text = rankText,
				Visible = function()
					return medalIcon() == ""
				end,
				Tags = {
					"ui-leaderboard-rank",
					"ui-leaderboard-tint",
					"ui-leaderboard-text",
					sizeTag,
					medalTag,
				},
			})
			local medal = Icon.new({
				app = app,
				name = "Medal",
				icon = medalIcon,
				size = function()
					return ICON[sizeNow()]
				end,
				visible = function()
					return medalIcon() ~= ""
				end,
			})
			medal.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
			medal.Instance.Position = UDim2.fromScale(0.5, 0.5)
			Element.hydrate(medal.Instance, { Tags = { "ui-leaderboard-medal-icon", medalTag } })
			local rankCell = Element.new("Frame", {
				Name = "RankCell",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = function()
					return UDim2.new(0, RANK_WIDTH[sizeNow()], 1, 0)
				end,
				rankLabel,
				medal.Instance,
			})
			local face = if avatars
				then Avatar.new({
					app = app,
					name = function()
						local e = entry()
						return (e and e.name) or ""
					end,
					userId = function()
						local e = entry()
						return (e and e.userId) or 0
					end,
					size = function()
						return AVATAR[sizeNow()]
					end,
					layoutOrder = 2,
				})
				else nil
			local nameLabel = Element.new("TextLabel", {
				Name = "Name",
				LayoutOrder = 3,
				Size = UDim2.fromScale(0, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = function()
					local e = entry()
					return (e and e.name) or ""
				end,
				Tags = { "ui-leaderboard-name", "ui-leaderboard-text", sizeTag },
				Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			})
			local valueLabel = Element.new("TextLabel", {
				Name = "Value",
				LayoutOrder = 4,
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = function()
					local e = entry()
					return if e then valueText(e.value) else ""
				end,
				Tags = {
					"ui-leaderboard-value",
					"ui-leaderboard-tint",
					"ui-leaderboard-text",
					sizeTag,
					medalTag,
				},
			})
			local root = Element.new("Frame", {
				Name = name,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Tags = { "ui-leaderboard-row", medalTag, ["ui-leaderboard-row-own"] = lit },
				Element.new("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = function()
						return UDim.new(0, GAP[sizeNow()])
					end,
				}),
				rankCell,
				if face then face.Instance else nil :: any,
				nameLabel,
				valueLabel,
			})
			-- The text cells are as tall as the avatar (or the text, with none)
			local function textHeight(): UDim2
				return UDim2.new(0, 0, 0, if avatars then Avatar.sizes[AVATAR[sizeNow()]] else 28)
			end
			Element.hydrate(nameLabel, { Size = textHeight })
			Element.hydrate(valueLabel, { Size = textHeight })
			Element.hydrate(rankCell, {
				Size = function()
					local height = textHeight().Y.Offset
					return UDim2.fromOffset(RANK_WIDTH[sizeNow()], height)
				end,
			})
			return root, rankLabel, medal.Instance, nameLabel, valueLabel
		end

		-- The list ----------------------------------------------------------------------------
		local indexById = Reactive.computed(function(): { [any]: number }
			local out = {}
			for index, row in rows() do
				out[idOf(row, index)] = index
			end
			return out
		end)
		local function isOwn(row: any): boolean
			local mine = own()
			return mine ~= nil and row ~= nil and idOf(row, 0) == idOf(mine, 0)
		end

		local parts: { [any]: { row: GuiObject, rank: TextLabel, medal: GuiObject, name: TextLabel, value: TextLabel } } =
			{}
		local count = 0
		h.rowFor = function(id: any): GuiObject?
			return parts[id] and parts[id].row
		end
		h.rankLabelFor = function(id: any): TextLabel?
			return parts[id] and parts[id].rank
		end
		h.medalFor = function(id: any): GuiObject?
			return parts[id] and parts[id].medal
		end
		h.nameLabelFor = function(id: any): TextLabel?
			return parts[id] and parts[id].name
		end
		h.valueLabelFor = function(id: any): TextLabel?
			return parts[id] and parts[id].value
		end
		h.rowCount = function(): number
			return count
		end

		local list = Element.new("Frame", {
			Name = "List",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = function()
				return not loading()
			end,
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			Element.each(rows, function(row: any, index: () -> number)
				local id = idOf(row, Reactive.untrack(index))
				local function at(): number?
					return indexById()[id]
				end
				local function entry(): any?
					local i = at()
					return if i then rows()[i] else nil
				end
				local function rank(): number?
					local e, i = entry(), at()
					return if e then (e.rank or i) else nil
				end
				local root, rankLabel, medal, nameLabel, valueLabel = buildRow(
					"Row",
					rank,
					function()
						local r = rank()
						return if r then tostring(r) else ""
					end,
					entry,
					function()
						return isOwn(entry())
					end
				)
				Element.hydrate(root, {
					LayoutOrder = function()
						return at() or 0
					end,
				})
				parts[id] =
					{ row = root, rank = rankLabel, medal = medal, name = nameLabel, value = valueLabel }
				count += 1
				Reactive.onCleanup(function()
					if parts[id] and parts[id].row == root then
						parts[id] = nil
						count -= 1
					end
				end)
				return root
			end, {
				key = function(row: any, index: number): any
					return idOf(row, index)
				end,
			}),
		})
		h.list = list

		-- The player's own row, pinned under the list when they are not in it -------------------
		local function listed(): boolean
			local mine = own()
			return mine ~= nil and indexById()[idOf(mine, 0)] ~= nil
		end
		local ownRow, ownRank, _, ownName, ownValue = buildRow(
			"Own",
			function()
				local mine = own()
				return mine and mine.rank
			end,
			function()
				local mine = own()
				if mine and mine.rank then
					return tostring(mine.rank)
				end
				return p.unranked or "-"
			end,
			own,
			function()
				return true
			end
		)
		h.ownRankLabel, h.ownNameLabel, h.ownValueLabel = ownRank, ownName, ownValue
		local pinned = Element.new("Frame", {
			Name = "Pinned",
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = function()
				return not loading() and own() ~= nil and not listed()
			end,
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = function()
					return UDim.new(0, GAP[sizeNow()])
				end,
			}),
			Element.new("Frame", {
				Name = "Divider",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 1),
				BorderSizePixel = 0,
				Tags = { "ui-leaderboard-divider" },
			}),
			Element.hydrate(ownRow, { LayoutOrder = 2 }),
		})
		h.pinned = pinned

		-- Loading and empty ---------------------------------------------------------------------
		local placeholders = {}
		for index = 1, math.max(1, p.placeholders or 5) do
			local skeleton = Skeleton.new({
				app = app,
				visible = loading,
				size = UDim2.new(1, 0, 0, SKELETON_HEIGHT[h:get("size")] or SKELETON_HEIGHT.md),
			})
			Element.hydrate(skeleton.Instance, {
				LayoutOrder = index,
				Size = function()
					return UDim2.new(1, 0, 0, SKELETON_HEIGHT[sizeNow()])
				end,
			})
			table.insert(placeholders, skeleton.Instance)
		end
		local skeletons = Element.new("Frame", {
			Name = "Skeletons",
			LayoutOrder = 0,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = loading,
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			table.unpack(placeholders),
		})
		h.skeletons = skeletons

		local emptyLabel = Element.new("TextLabel", {
			Name = "Empty",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 48),
			Text = p.empty or "",
			Visible = function()
				return p.empty ~= nil and not loading() and #rows() == 0
			end,
			Tags = { "ui-leaderboard-empty" },
		})
		h.emptyLabel = emptyLabel

		return Element.new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = h:ref("visible"),
			Tags = { "ui-leaderboard" },
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = function()
					return UDim.new(0, math.floor(GAP[sizeNow()] / 2))
				end,
			}),
			skeletons,
			list,
			emptyLabel,
			pinned,
		})
	end,
}

function Leaderboard.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Leaderboard
