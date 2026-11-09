--!strict
--[[
	Baseline: lines up the text of a row's children where the letters sit, not on
	their boxes, so a small line beside a big title reads as one line.

		local sizes = Baseline.offsets({ 40, 18 })   -- { 0, 4.18 }: lift the 18 by that
		Baseline.follow(row, function() return beside() end)

	The row lays its children out bottom-aligned; follow lifts each text child by
	the difference between its descent and the biggest text's, with a UIPadding
	named "BaselinePadding" (a child with its own UIPadding is left alone). A
	child's text is the child itself (a TextLabel, TextButton or TextBox) or its
	first text descendant (a Marquee); hidden children do not count. Sizes are the
	styled TextSize, capped at Roblox's 100.

	Baseline.descent is how far the baseline sits above the bottom of a line's box,
	as a share of the text size: 0.19 for the theme's Gotham SSm at every weight
	(measured).
]]

local Reactive = require(script.Parent.Reactive)

local Baseline = {}

Baseline.descent = 0.19
Baseline.maxTextSize = 100
Baseline.paddingName = "BaselinePadding"

-- How far to lift each size so all their baselines meet the biggest one's (bottoms aligned).
function Baseline.offsets(sizes: { number }): { number }
	local biggest = 0
	for _, size in sizes do
		biggest = math.max(biggest, math.min(size, Baseline.maxTextSize))
	end
	local out = {}
	for i, size in sizes do
		out[i] = Baseline.descent * (biggest - math.min(size, Baseline.maxTextSize))
	end
	return out
end

local function isText(instance: Instance): boolean
	return instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")
end

-- The text that sets a child's baseline: the child, or its first text descendant
function Baseline.textOf(child: Instance): GuiObject?
	if isText(child) then
		return child :: GuiObject
	end
	for _, descendant in child:GetDescendants() do
		if isText(descendant) then
			return descendant :: GuiObject
		end
	end
	return nil
end

-- A text's size as drawn: the styled size when a style sets it
function Baseline.sizeOf(text: GuiObject): number
	local ok, styled = pcall(function()
		return (text :: any):GetStyled("TextSize")
	end)
	local size = if ok and type(styled) == "number" and styled > 0 then styled else (text :: any).TextSize
	return math.min(size, Baseline.maxTextSize)
end

--[[
	Keeps the children of `row` on one baseline while `active` (a getter) is true,
	and takes the lifts away while it is false. Call it in a scope (a component's
	render): it stops with the scope. Returns a function that applies it now.
]]
function Baseline.follow(row: Instance, active: () -> boolean): () -> ()
	local connections: { RBXScriptConnection } = {}
	local watched: { [Instance]: { RBXScriptConnection } } = {}
	local on = false

	local function lift(child: GuiObject, amount: number)
		local existing = child:FindFirstChild(Baseline.paddingName) :: UIPadding?
		if not (on and amount >= 0.5) then
			if existing then
				existing:Destroy()
			end
			return
		end
		local padding: UIPadding
		if existing then
			padding = existing
		else
			if child:FindFirstChildOfClass("UIPadding") then
				return -- the child's own padding: not ours to share
			end
			padding = Instance.new("UIPadding")
			padding.Name = Baseline.paddingName
			padding.Parent = child
		end
		local value = UDim.new(0, math.round(amount))
		if padding.PaddingBottom ~= value then
			padding.PaddingBottom = value
		end
	end

	local function update()
		local children: { GuiObject } = {}
		local sizes: { number } = {}
		for _, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				local text = Baseline.textOf(child)
				if text and child.Visible then
					table.insert(children, child)
					table.insert(sizes, Baseline.sizeOf(text))
				else
					lift(child, 0)
				end
			end
		end
		local offsets = Baseline.offsets(sizes)
		for i, child in children do
			lift(child, offsets[i])
		end
	end

	local function watch(child: Instance)
		if watched[child] or not child:IsA("GuiObject") then
			return
		end
		local list = { child:GetPropertyChangedSignal("Visible"):Connect(update) }
		local text = Baseline.textOf(child)
		if text then
			table.insert(list, (text :: any):GetPropertyChangedSignal("TextSize"):Connect(update))
			pcall(function()
				table.insert(list, (text :: any).StyledPropertiesChanged:Connect(update))
			end)
		end
		watched[child] = list
	end
	local function unwatch(child: Instance)
		local list: { RBXScriptConnection } = watched[child] or {}
		for _, connection in list do
			connection:Disconnect()
		end
		watched[child] = nil
	end

	for _, child in row:GetChildren() do
		watch(child)
	end
	table.insert(
		connections,
		row.ChildAdded:Connect(function(child)
			watch(child)
			update()
		end)
	)
	table.insert(
		connections,
		row.ChildRemoved:Connect(function(child)
			unwatch(child)
			update()
		end)
	)

	Reactive.watchEffect(function()
		on = active() == true
		Reactive.untrack(update)
	end)
	Reactive.onCleanup(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for child in watched do
			unwatch(child)
		end
	end)
	return update
end

return Baseline
