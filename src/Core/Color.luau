--!strict
--[[
	Color: named colours on parts of the UI (ADR 0052).

		Lucy.color(container, "hype")        -- a colour's name (the theme's `colors`), a ref or
		                                      -- getter of one, or nil for none; returns stop()
		Lucy.Button.new({ color = "hype" })   -- the same on a component's root

	A coloured container gives its colour to itself and to every tagged element inside it, as the
	tag ui-color-<name> (and ui-colored, whatever the colour); the theme's rules written in $Color
	have a copy for each colour on that tag (Core/Theme). The nearest coloured container wins, as a
	CSS variable does: a hype card in a premium panel is hype inside, premium round it. Elements
	added later get the colour as they arrive, and an element moved out of a container loses it.
	Roblox's tokens cannot be scoped below a ScreenGui, so this is how a colour reaches part of one.

	The container's colour is its attribute LucyColor; nil makes it no container (its elements take
	the colour of the one round it). Inside an owner (a component's render, an effect scope) it stops
	with the owner; stop() takes its colour off everything it gave it.
]]

local Reactive = require(script.Parent.Reactive)

local Color = {}

Color.attribute = "LucyColor"
local PREFIX = "ui-color-"
-- On everything coloured, whatever the colour: for a scoped rule that holds in any colour
local COLORED = "ui-colored"

-- The colour of the nearest coloured container at or above `instance`
local function inherited(instance: Instance?): string?
	local node = instance
	while node do
		local value = node:GetAttribute(Color.attribute)
		if type(value) == "string" and value ~= "" then
			return value
		end
		node = node.Parent
	end
	return nil
end

local function isColorTag(tag: string): boolean
	return tag == COLORED or string.sub(tag, 1, #PREFIX) == PREFIX
end

-- Whether a rule could pick `instance` by a tag (it has one besides a colour)
local function tagged(instance: Instance): boolean
	for _, tag in instance:GetTags() do
		if not isColorTag(tag) then
			return true
		end
	end
	return false
end

-- Gives `instance` exactly the colour tag for `colour` and ui-colored, or neither
local function paint(instance: Instance, colour: string?)
	local want = if colour then PREFIX .. colour else nil
	for _, tag in instance:GetTags() do
		if isColorTag(tag) and tag ~= want and not (want and tag == COLORED) then
			instance:RemoveTag(tag)
		end
	end
	if want and tagged(instance) and not instance:HasTag(want) then
		instance:AddTag(want)
		instance:AddTag(COLORED)
	end
end

-- Paints a whole subtree, top down, each element with the colour of its nearest container
local function paintTree(root: Instance, above: string?)
	local own = root:GetAttribute(Color.attribute)
	local colour = if type(own) == "string" and own ~= "" then own else above
	paint(root, colour)
	for _, child in root:GetChildren() do
		paintTree(child, colour)
	end
end

-- The nearest coloured container strictly above `instance`
local function containerAbove(instance: Instance): Instance?
	local node = instance.Parent
	while node do
		local value = node:GetAttribute(Color.attribute)
		if type(value) == "string" and value ~= "" then
			return node
		end
		node = node.Parent
	end
	return nil
end

function Color.scope(container: Instance, name: any): () -> ()
	local stopped = false
	local function set(colour: string?)
		container:SetAttribute(Color.attribute, colour)
		paintTree(container, inherited(container.Parent))
	end

	-- What arrives: each element painted by the container nearest it, so an outer container leaves
	-- an inner one's elements alone
	local added = container.DescendantAdded:Connect(function(descendant: Instance)
		if containerAbove(descendant) ~= container then
			return
		end
		paint(descendant, inherited(descendant))
	end)
	-- What leaves: checked once at the end of the frame, when a move has landed. Something
	-- destroyed has no parent then and is left alone
	local leaving: { [Instance]: boolean } = {}
	local checking = false
	local removing = container.DescendantRemoving:Connect(function(descendant: Instance)
		if not descendant:HasTag(COLORED) then
			return
		end
		leaving[descendant] = true
		if not checking then
			checking = true
			task.defer(function()
				checking = false
				local list = leaving
				leaving = {}
				for instance in list do
					if instance.Parent and not instance:IsDescendantOf(container) then
						paint(instance, inherited(instance))
					end
				end
			end)
		end
	end)

	local scope = Reactive.effectScope()
	local function stop()
		if stopped then
			return
		end
		stopped = true
		added:Disconnect()
		removing:Disconnect()
		scope:stop()
		set(nil)
	end
	scope:run(function()
		if type(name) == "function" or Reactive.isRef(name) then
			-- Why a watch: a new colour retags elements, a side effect with nothing to bind
			Reactive.watch(name, function(colour: any)
				if not stopped then
					set(if type(colour) == "string" and colour ~= "" then colour else nil)
				end
			end, { immediate = true })
		else
			set(if type(name) == "string" and name ~= "" then name else nil)
		end
	end)
	-- Inside an owner, it stops with the owner
	if Reactive._hasOwner() then
		Reactive.onCleanup(stop)
	end
	return stop
end

return Color
