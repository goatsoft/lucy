--!strict
--[[
	Heading: a title with a description, as Dialog and Sheet show them (not a component of its
	own: their header part).

		local text, title, description = Heading.new(app, {
			title = h:ref("title"), description = h:ref("description"),
			titleTag = "ui-dialog-title", descriptionTag = "ui-dialog-description",
		})

	The title over its description, both wrapping. On a short screen (a phone held sideways,
	input.height "short") the description sits beside the title on one line, so the header takes
	one line of the little height there is; a description too long for the line scrolls across and
	back (a Marquee) rather than being cut short. Either hides while its text is empty. Call it in
	a scope (a component's render).

	description is the wrapping label (the one a game styles); the one-line description beside the
	title is a Marquee in the muted style.
]]

local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Marquee = require(script.Parent.Marquee)

local Heading = {}

-- The room between the title and its description: under it, and beside it on a short screen
Heading.gap = 6
Heading.besideGap = 12

function Heading.new(app: any, props: { [string]: any }): (Frame, TextLabel, TextLabel)
	local beside = Composables.useResponsive(app, { short = true, default = false })
	local titleText: () -> string = props.title
	local descriptionText: () -> string = props.description
	local function hasDescription(): boolean
		return descriptionText() ~= ""
	end

	local title = Element.new("TextLabel", {
		Size = function(): UDim2
			return if beside() then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0)
		end,
		AutomaticSize = function(): Enum.AutomaticSize
			return if beside() then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y
		end,
		TextWrapped = function(): boolean
			return not beside()
		end,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Text = titleText,
		Visible = function()
			return titleText() ~= ""
		end,
		Tags = { props.titleTag },
	}) :: TextLabel

	-- Under the title: wrapping
	local description = Element.new("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Text = descriptionText,
		Visible = function()
			return hasDescription() and not beside()
		end,
		Tags = { props.descriptionTag },
	}) :: TextLabel

	-- Beside it: the rest of the line, scrolling when it is longer
	local line = Marquee.new({
		app = app,
		text = descriptionText,
		variant = "muted",
		visible = function()
			return hasDescription() and beside()
		end,
	})
	Element.hydrate(line.Instance, {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})

	local frame = Element.new("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Element.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = function(): Enum.FillDirection
				return if beside() then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
			end,
			-- Beside it, the description sits on the title's bottom edge, near its baseline
			VerticalAlignment = function(): Enum.VerticalAlignment
				return if beside() then Enum.VerticalAlignment.Bottom else Enum.VerticalAlignment.Top
			end,
			Padding = function(): UDim
				return UDim.new(0, if beside() then Heading.besideGap else Heading.gap)
			end,
		}),
		title,
		description,
		line.Instance,
	}) :: Frame
	return frame, title, description
end

return Heading
