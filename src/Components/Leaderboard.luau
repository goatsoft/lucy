--!strict
--[[
	Leaderboard: ranked players, best first, laid out as a podium. 1st is the board's headline: a
	big headshot, the name and value in the display face. 2nd and 3rd sit under it a step smaller,
	with their headshots. Everyone after them is a plain line of text. The player's own row is lit;
	when they are not in the list it is pinned under it, a step smaller than 2nd and 3rd.

		Leaderboard.new({
			rows = entries,            -- { { userId, name, value, rank? } }, best first; an array,
			                           -- a ref or a getter. rank defaults to the row's place
			own = mine,                -- the player's entry (or nil): lit when listed, else pinned
			unranked = "100+",         -- the pinned rank when own.rank is nil (or a ref or getter)
			format = function(value) return `{value} PTS` end, -- default: 14,850
			medals = { "set:queen", "set:crown", "set:crown" }, -- icons for 1st to 3rd, in place
			                           -- of the #: 1, 2, 3, then #4 on; false for no medal colours at all (a ref
			                           -- or getter too: one board with medals, the next without)
			podium = true,             -- false: every row the same, as a plain list
			avatars = "top",           -- headshots on the podium and the player's row; true on
			                           -- every row, false on none (no userId: a monogram)
			avatarShape = "circle",    -- circle | square (rounded corners)
			loading = false,           -- skeleton rows in place of the list
			placeholders = 5,          -- how many skeleton rows
			empty = "No one yet",      -- shown with no rows
			size = "md",               -- sm | md | lg: the whole board's scale
			height = 420,              -- pixels (or a ref or getter): the whole board's height. The
			                           -- rows scroll in what the pinned row leaves, so the board keeps
			                           -- one size while it loads, empties and fills
		})

	Each row has a tier: first, podium (2nd and 3rd), rest, or own (the player's row, listed past
	the podium or pinned). A tier sets the headshot and type sizes, scaled by `size`. Ranks read
	#1, #2, #3, or 1, 2, 3 beside medal icons (#4 on, and the pinned row, keep the #). A name is
	shown in full: a long one scrolls back and forth (a Marquee; nameLabelFor gives its strip). Rows are keyed by userId (or name), so new data updates rows in place and moves
	them. Colours come from style rules: $MedalGold, $MedalSilver, $MedalBronze for the top three,
	$Accent and $Ring for the player's row; 1st's name and value are in $FontDisplay.

	Parts: board.list, board.pinned (the own row's frame, with a separator above), board.scroller
	(the ScrollArea round the rows, with height), board.skeletons, board.emptyLabel,
	board.rowFor(id), board.tierOf(id), board.rankLabelFor(id), board.medalFor(id),
	board.avatarFor(id), board.nameLabelFor(id), board.valueLabelFor(id), board.rowCount(),
	board.ownRankLabel, board.ownAvatar, board.ownNameLabel, board.ownValueLabel.
	A row is its headshot, rank, name and value in a line, with a thin separator under it (none
	under the last or the pinned row); the player's row has a quiet fill, no outline.

	State keys: size, visible.
]]

local Avatar = require(script.Parent.Avatar)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Marquee = require(script.Parent.Marquee)
local ScrollArea = require(script.Parent.ScrollArea)
local Skeleton = require(script.Parent.Skeleton)

local Leaderboard = {}

Leaderboard.sizes = { "sm", "md", "lg" }
Leaderboard.MEDALS = { "gold", "silver", "bronze" }
Leaderboard.tiers = { "first", "podium", "own", "rest" }
Leaderboard.avatarShapes = { "circle", "square" }

-- Per tier and board size: the headshot (an Avatar size, or false), the type and medal icon sizes,
-- and the row's padding (pixels)
type Tier = {
	avatar: { [string]: string | false },
	text: { [string]: string },
	icon: { [string]: string },
	pad: { [string]: number },
}
local TIER: { [string]: Tier } = {
	first = {
		avatar = { sm = "md", md = "lg", lg = "xl" },
		text = { sm = "TextXl", md = "Text2xl", lg = "Text3xl" },
		icon = { sm = "md", md = "lg", lg = "xl" },
		pad = { sm = 8, md = 12, lg = 16 },
	},
	podium = {
		avatar = { sm = "sm", md = "md", lg = "lg" },
		text = { sm = "TextBase", md = "TextLg", lg = "TextXl" },
		icon = { sm = "sm", md = "md", lg = "lg" },
		pad = { sm = 6, md = 8, lg = 10 },
	},
	own = {
		avatar = { sm = "sm", md = "sm", lg = "md" },
		text = { sm = "TextSm", md = "TextBase", lg = "TextLg" },
		icon = { sm = "sm", md = "sm", lg = "md" },
		pad = { sm = 6, md = 8, lg = 8 },
	},
	rest = {
		avatar = { sm = false, md = false, lg = false },
		text = { sm = "TextSm", md = "TextBase", lg = "TextLg" },
		icon = { sm = "sm", md = "sm", lg = "md" },
		pad = { sm = 4, md = 6, lg = 6 },
	},
}
Leaderboard.TIER = TIER

-- The rank column (pixels), wide enough for the medal and #100+; every row keeps it so the names
-- line up
local RANK_WIDTH = { sm = 44, md = 56, lg = 72 }
local MEDAL_RANK_WIDTH = { sm = 64, md = 84, lg = 112 }
-- The headshot column is 1st's headshot wide on every row, each headshot centred in it, so the
-- ranks and names line up under 1st's
local LIST_FACE = { sm = "sm", md = "md", lg = "lg" }
local GAP = { sm = 8, md = 12, lg = 16 }
local SKELETON_HEIGHT = { sm = 32, md = 40, lg = 56 }

local BASE, TYPE, OWN, FIRST, MEDAL = 0, 10, 20, 30, 50
-- A name is a Marquee's strip, styled as Text too (up to priority 10): its own rules sit above
local NAME, NAME_TYPE = 15, 16

local rules: { Component.Rule } = {
	{
		selector = ".ui-leaderboard-row",
		priority = BASE,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-leaderboard-row::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusLg" },
	},
	-- The player's row: a quiet fill, no outline
	{
		selector = ".ui-leaderboard-row-own",
		priority = OWN,
		properties = { BackgroundTransparency = 0 },
	},
	-- A thin line between rows
	{
		selector = ".ui-leaderboard-separator",
		priority = BASE,
		properties = { BackgroundColor3 = "$Border" },
	},
	-- The lit row is the avatar's own colour, so its circle stands on the background's
	{
		selector = ".ui-leaderboard-avatar-own",
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
		},
	},
	{
		selector = ".ui-leaderboard-name",
		priority = NAME,
		properties = { BackgroundTransparency = 1, TextColor3 = "$Foreground", FontFace = "$FontSansMedium" },
	},
	{
		selector = ".ui-leaderboard-value",
		priority = BASE,
		properties = { BackgroundTransparency = 1, TextColor3 = "$Foreground", FontFace = "$FontSansBold" },
	},
	-- 1st's name and value in the display face
	{
		selector = ".ui-leaderboard-display",
		priority = FIRST,
		properties = { FontFace = "$FontDisplay" },
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
-- The type sizes the tiers use, one tag each
local typeTokens: { [string]: boolean } = {}
for _, tier in TIER do
	for _, token in tier.text do
		typeTokens[token] = true
	end
end
for token in typeTokens do
	table.insert(rules, {
		selector = `.ui-leaderboard-type-{token}`,
		priority = TYPE,
		properties = { TextSize = `${token}` },
	})
	table.insert(rules, {
		selector = `.ui-leaderboard-name.ui-leaderboard-type-{token}`,
		priority = NAME_TYPE,
		properties = { TextSize = `${token}` },
	})
end
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
		local function medalIcons(): { string }?
			local m = Reactive.toValue(p.medals)
			return if type(m) == "table" then m else nil
		end
		local function useMedals(): boolean
			return Reactive.toValue(p.medals) ~= false
		end
		local podium = p.podium ~= false
		local avatarShape = p.avatarShape or "circle"
		if not table.find(Leaderboard.avatarShapes, avatarShape) then
			error(
				`[Lucy] unknown Leaderboard avatarShape "{avatarShape}" (expected {table.concat(
					Leaderboard.avatarShapes,
					", "
				)})`,
				0
			)
		end
		local avatars = if p.avatars == nil then "top" else p.avatars
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
			return if useMedals() and rank then Leaderboard.MEDALS[rank] else nil
		end

		-- One row, from getters of its rank, entry, whether it is the player's and whether it is the
		-- pinned row
		local function buildRow(
			name: string,
			rank: () -> number?,
			rankText: () -> string,
			entry: () -> any?,
			lit: () -> boolean,
			pinned: boolean,
			last: () -> boolean
		)
			local function tier(): string
				if pinned then
					return "own"
				end
				local r = rank()
				if podium and r == 1 then
					return "first"
				elseif podium and r ~= nil and r <= 3 then
					return "podium"
				elseif lit() then
					return "own"
				end
				return if podium then "rest" else "podium"
			end
			local function spec_(): any
				return TIER[tier()]
			end
			local function typeTag(): string
				return `ui-leaderboard-type-{spec_().text[sizeNow()]}`
			end
			local function medalTag(): string?
				local medal = medalOf(rank())
				return if medal and not pinned then `ui-leaderboard-medal-{medal}` else nil
			end
			local function medalIcon(): string
				local icons = medalIcons()
				local r = rank()
				return if icons and r and icons[r] and not pinned then icons[r] else ""
			end
			local function displayTag(): string?
				return if tier() == "first" then "ui-leaderboard-display" else nil
			end

			-- Rank: the medal, then #n
			local medal = Icon.new({
				app = app,
				name = "Medal",
				icon = medalIcon,
				size = function()
					return spec_().icon[sizeNow()]
				end,
				visible = function()
					return medalIcon() ~= ""
				end,
			})
			Element.hydrate(
				medal.Instance,
				{ LayoutOrder = 1, Tags = { "ui-leaderboard-medal-icon" :: any, medalTag } }
			)
			local rankLabel = Element.new("TextLabel", {
				Name = "Rank",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				-- Beside a crown the number stands alone: #4 on, and the pinned row, keep the #
				Text = function()
					local text = rankText()
					return if medalIcon() ~= "" then (text:gsub("^#", "")) else text
				end,
				Tags = { "ui-leaderboard-rank" :: any, "ui-leaderboard-tint", typeTag, medalTag, displayTag },
			})
			local rankCell = Element.new("Frame", {
				Name = "RankCell",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Size = function()
					local widths = if medalIcons() then MEDAL_RANK_WIDTH else RANK_WIDTH
					return UDim2.fromOffset(widths[sizeNow()], 0)
				end,
				AutomaticSize = Enum.AutomaticSize.Y,
				-- The medal, then the number, straight after the headshot
				Element.new("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
				}),
				medal.Instance,
				rankLabel,
			})

			-- Headshot: the tier's size; the column is 2nd's width below 1st, so names line up
			local function faceSize(): string?
				local s = spec_().avatar[sizeNow()]
				if avatars == false then
					return nil
				elseif avatars == true and not s then
					return LIST_FACE[sizeNow()]
				end
				return if s then s else nil
			end
			local face = if avatars ~= false
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
						return faceSize() or "sm"
					end,
					visible = function()
						return faceSize() ~= nil
					end,
					square = avatarShape == "square",
				})
				else nil
			if face then
				Element.hydrate(face.Instance, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Tags = { ["ui-leaderboard-avatar-own"] = lit },
				})
			end
			local faceCell = if face
				then Element.new("Frame", {
					Name = "AvatarCell",
					LayoutOrder = 1,
					BackgroundTransparency = 1,
					Size = function()
						local s = faceSize()
						local first = TIER.first.avatar[sizeNow()]
						local w = Avatar.sizes[if first then first else LIST_FACE[sizeNow()]]
						return UDim2.fromOffset(w, if s then Avatar.sizes[s] else 0)
					end,
					face.Instance,
				})
				else nil

			-- The name, in full: a long one scrolls back and forth in what the row leaves it
			local nameMarquee = Marquee.new({
				app = app,
				text = function()
					local e = entry()
					return (e and e.name) or ""
				end,
			})
			Element.hydrate(nameMarquee.Instance, {
				Name = "Name",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			})
			local nameLabel: TextLabel = nameMarquee.strip
			Element.hydrate(nameLabel, { Tags = { "ui-leaderboard-name" :: any, typeTag, displayTag } })
			local valueLabel = Element.new("TextLabel", {
				Name = "Value",
				LayoutOrder = 4,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = function()
					local e = entry()
					return if e then valueText(e.value) else ""
				end,
				Tags = { "ui-leaderboard-value" :: any, "ui-leaderboard-tint", typeTag, medalTag, displayTag },
			})
			local function pad(): UDim
				return UDim.new(0, spec_().pad[sizeNow()])
			end
			-- The row's cells in a line: headshot, rank, name, value
			local line = Element.new("Frame", {
				Name = "Line",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Element.new("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = pad,
					PaddingBottom = pad,
				}),
				Element.new("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = function()
						return UDim.new(0, GAP[sizeNow()])
					end,
				}),
				faceCell :: any,
				rankCell,
				nameMarquee.Instance,
				valueLabel,
			})
			-- Under each listed row but the last, and under none when pinned
			local separator = Element.new("Frame", {
				Name = "Separator",
				LayoutOrder = 2,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
				Visible = function()
					return not pinned and not last()
				end,
				Tags = { "ui-leaderboard-separator" },
			})
			local root = Element.new("Frame", {
				Name = name,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Tags = {
					"ui-leaderboard-row" :: any,
					function()
						return `ui-leaderboard-tier-{tier()}`
					end,
					medalTag,
					["ui-leaderboard-row-own"] = lit,
				},
				Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
				line,
				separator,
			})
			return {
				row = root,
				rank = rankLabel,
				medal = medal.Instance,
				name = nameLabel,
				value = valueLabel,
				avatar = if face then face.Instance else nil,
				tier = tier,
			}
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

		local parts: { [any]: any } = {}
		local count = 0
		local function part(id: any, key: string): any
			return parts[id] and parts[id][key]
		end
		h.rowFor = function(id: any): GuiObject?
			return part(id, "row")
		end
		h.rankLabelFor = function(id: any): TextLabel?
			return part(id, "rank")
		end
		h.medalFor = function(id: any): GuiObject?
			return part(id, "medal")
		end
		h.avatarFor = function(id: any): GuiObject?
			return part(id, "avatar")
		end
		h.nameLabelFor = function(id: any): TextLabel?
			return part(id, "name")
		end
		h.valueLabelFor = function(id: any): TextLabel?
			return part(id, "value")
		end
		h.tierOf = function(id: any): string?
			local t = part(id, "tier")
			return if t then t() else nil
		end
		h.rowCount = function(): number
			return count
		end

		local function spacing(): UDim
			return UDim.new(0, 0)
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
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = spacing }),
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
				local built = buildRow(
					"Row",
					rank,
					function()
						local r = rank()
						return if r then `#{r}` else ""
					end,
					entry,
					function()
						return isOwn(entry())
					end,
					false,
					function()
						return at() == #rows()
					end
				)
				Element.hydrate(built.row, {
					LayoutOrder = function()
						return at() or 0
					end,
				})
				parts[id] = built
				count += 1
				Reactive.onCleanup(function()
					if parts[id] == built then
						parts[id] = nil
						count -= 1
					end
				end)
				return built.row
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
		local ownBuilt = buildRow(
			"Own",
			function()
				local mine = own()
				return mine and mine.rank
			end,
			function()
				local mine = own()
				if mine and mine.rank then
					return `#{mine.rank}`
				end
				return Reactive.toValue(p.unranked) or "-"
			end,
			own,
			function()
				return true
			end,
			true,
			function()
				return true
			end
		)
		h.ownRankLabel, h.ownNameLabel, h.ownValueLabel, h.ownAvatar =
			ownBuilt.rank, ownBuilt.name, ownBuilt.value, ownBuilt.avatar
		local pinned = Element.new("Frame", {
			Name = "Pinned",
			LayoutOrder = 2,
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
			Element.hydrate(ownBuilt.row, { LayoutOrder = 2 }),
		})
		h.pinned = pinned

		-- Loading and empty ---------------------------------------------------------------------
		local placeholders = {}
		for index = 1, math.max(1, p.placeholders or 5) do
			local skeleton = Skeleton.new({ app = app, visible = loading })
			Element.hydrate(skeleton.Instance, {
				LayoutOrder = index,
				Size = function()
					-- 1st's placeholder as tall as its headshot row
					local h_ = SKELETON_HEIGHT[sizeNow()]
					return UDim2.new(1, 0, 0, if index == 1 and podium then h_ * 2 else h_)
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
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			table.unpack(placeholders),
		})
		h.skeletons = skeletons

		local emptyLabel = Element.new("TextLabel", {
			Name = "Empty",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 48),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = p.empty or "",
			TextWrapped = true,
			Visible = function()
				return p.empty ~= nil and not loading() and #rows() == 0
			end,
			Tags = {
				"ui-leaderboard-empty" :: any,
				function()
					return `ui-leaderboard-type-{TIER.podium.text[sizeNow()]}`
				end,
			},
		})
		h.emptyLabel = emptyLabel

		local rowsHolder = Element.new("Frame", {
			Name = "Rows",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = spacing }),
			skeletons,
			list,
			emptyLabel,
		})
		-- A fixed height for the whole board: the rows scroll in what the pinned row leaves
		local fixed = p.height ~= nil
		local rowsPart: any = rowsHolder
		if fixed then
			local scroller = ScrollArea.new({
				app = app,
				name = "Scroll",
				layoutOrder = 1,
				size = UDim2.fromScale(1, 0),
				children = { rowsHolder },
			})
			Element.hydrate(scroller.Instance, {
				Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			})
			h.scroller = scroller
			rowsPart = scroller.Instance
		end

		return Element.new("Frame", {
			Size = function(): UDim2
				if fixed then
					return UDim2.new(1, 0, 0, Reactive.toValue(p.height) or 0)
				end
				return UDim2.fromScale(1, 0)
			end,
			AutomaticSize = if fixed then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = h:ref("visible"),
			Tags = { "ui-leaderboard" },
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = function()
					return UDim.new(0, GAP[sizeNow()])
				end,
			}),
			rowsPart,
			pinned,
		})
	end,
}

function Leaderboard.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Leaderboard
