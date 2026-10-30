--[[
	Element: declarative instances bound to reactive state (ADR 0014).

		local count = Lucy.ref(0)

		Lucy.new "TextButton" {
			Size = UDim2.fromOffset(200, 40),
			Text = function() return `Clicked {count()}` end,   -- any getter, ref or computed
			Tags = { "card", ["card-active"] = isActive },      -- toggled by a boolean
			Attributes = { Health = hp },
			[Lucy.on "Activated"] = function() count(count() + 1) end,
			[Lucy.changed "AbsoluteSize"] = function(size) end,
			[Lucy.model "Text"] = text,                        -- two-way (TextBox)
			[Lucy.out "AbsoluteSize"] = size,                  -- property -> ref
			[Lucy.instance] = buttonRef,                       -- the instance -> ref
			Parent = gui,

			Lucy.new "UICorner" {},                            -- children: the array part
			Lucy.show(open, function() return Lucy.new "Frame" {} end),
			Lucy.each(items, function(item, index) return Lucy.Text.new({ text = item.name }) end),
		}

		Lucy.hydrate(existingGui.Title) { Text = title }   -- bring Studio-built UI to life

	Lifetime: an element's bindings live in a scope owned by whatever created it (an
	effect, a show branch, an each item, an effectScope). When that owner stops, the
	element is destroyed. When the instance is destroyed by anyone, its bindings stop.
	Hydrated instances are never destroyed by Lucy, only unbound.
]]

local Reactive = require(script.Parent.Reactive)

local Element = {}

local KEY = "__lucyKey"
local ORDER_SLOT = 100000 -- LayoutOrder room per child position, for show/each slots
local CALLBACKS = { OnInvoke = true, OnClientInvoke = true, OnServerInvoke = true }

local ordered: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function key(kind: string, name: string?): any
	return table.freeze({ [KEY] = kind, name = name })
end

-- [Lucy.on "Activated"] = function(...) end
function Element.on(event: string): any
	return key("on", event)
end

-- [Lucy.changed "Text"] = function(newValue) end
function Element.changed(property: string): any
	return key("changed", property)
end

-- [Lucy.out "AbsoluteSize"] = someRef: the ref follows the property.
function Element.out(property: string): any
	return key("out", property)
end

-- [Lucy.model "Text"] = someRef: two-way binding.
function Element.model(property: string): any
	return key("model", property)
end

-- [Lucy.instance] = someRef or function(instance) end
Element.instance = key("instance")

local function describe(instance: Instance, property: string): string
	return `{instance.ClassName}.{property}`
end

local function assign(instance: Instance, property: string, value: any)
	local ok, err = pcall(function()
		(instance :: any)[property] = value
	end)
	if not ok then
		error(`[Lucy] {describe(instance, property)}: {err}`, 0)
	end
end

local function bindProperty(instance: Instance, property: string, value: any)
	if type(value) == "function" and not CALLBACKS[property] then
		Reactive.watchEffect(function()
			assign(instance, property, value())
		end)
	else
		assign(instance, property, value)
	end
end

local function collectTags(value: any, into: { [string]: boolean })
	if type(value) == "string" then
		into[value] = true
	elseif type(value) == "table" then
		for k, v in value do
			if type(k) == "number" then
				collectTags(v, into)
			elseif Reactive.toValue(v) then
				into[k] = true
			end
		end
	end
end

local function bindTags(instance: Instance, tags: any)
	if type(tags) == "function" then
		local applied: { [string]: boolean } = {}
		Reactive.watchEffect(function()
			local want = {}
			collectTags(tags(), want)
			for tag in applied do
				if not want[tag] then
					instance:RemoveTag(tag)
				end
			end
			for tag in want do
				instance:AddTag(tag)
			end
			applied = want
		end)
		return
	end
	for k, v in tags do
		if type(k) == "number" then
			if type(v) == "function" then
				bindTags(instance, v)
			else
				instance:AddTag(v)
			end
		elseif type(v) == "function" then
			Reactive.watchEffect(function()
				if v() then
					instance:AddTag(k)
				else
					instance:RemoveTag(k)
				end
			end)
		elseif v then
			instance:AddTag(k)
		end
	end
end

local function bindAttributes(instance: Instance, attributes: { [string]: any })
	for name, value in attributes do
		if type(value) == "function" then
			Reactive.watchEffect(function()
				instance:SetAttribute(name, value())
			end)
		else
			instance:SetAttribute(name, value)
		end
	end
end

local function connect(signal: RBXScriptSignal, handler: (...any) -> ())
	local connection = signal:Connect(handler)
	Reactive.onCleanup(function()
		connection:Disconnect()
	end)
end

local function bindSpecial(instance: Instance, special: any, value: any)
	local kind, name = special[KEY], special.name
	if kind == "on" then
		connect((instance :: any)[name], value)
	elseif kind == "changed" then
		connect(instance:GetPropertyChangedSignal(name), function()
			value((instance :: any)[name])
		end)
	elseif kind == "out" or kind == "model" then
		assert(Reactive.isRef(value), `[Lucy] {kind} "{name}" needs a ref`)
		if kind == "model" then
			bindProperty(instance, name, value)
		else
			value((instance :: any)[name])
		end
		connect(instance:GetPropertyChangedSignal(name), function()
			value((instance :: any)[name])
		end)
	elseif kind == "instance" then
		value(instance)
	end
end

-- Flattens children: Instances, handles (.Instance), arrays, getters; skips nil/false.
local function collect(value: any, into: { Instance }): { Instance }
	local kind = typeof(value)
	if kind == "Instance" then
		table.insert(into, value)
	elseif kind == "function" then
		collect(value(), into)
	elseif kind == "table" then
		local instance = value.Instance
		if typeof(instance) == "Instance" then
			table.insert(into, instance)
		else
			for i = 1, #value do
				collect(value[i], into)
			end
		end
	end
	return into
end

local function order(child: Instance, layoutOrder: number)
	if child:IsA("GuiObject") and (child.LayoutOrder == 0 or ordered[child]) then
		child.LayoutOrder = layoutOrder
		ordered[child] = true
	end
end

local function bindChild(instance: Instance, child: any, position: number)
	local base = position * ORDER_SLOT
	if type(child) ~= "function" then
		for j, item in collect(child, {}) do
			order(item, base + j)
			item.Parent = instance
		end
		return
	end
	-- A reactive slot: show, each, or any getter returning children.
	local current: { Instance } = {}
	Reactive.watchEffect(function()
		local children = collect(child, {})
		local keep = {}
		for j, item in children do
			keep[item] = true
			order(item, base + j)
			if item.Parent ~= instance then
				item.Parent = instance
			end
		end
		for _, item in current do
			if not keep[item] and item.Parent == instance then
				item.Parent = nil
			end
		end
		current = children
	end)
end

local function apply(instance: Instance, props: { [any]: any }, owned: boolean): Instance
	local scope = Reactive.effectScope()
	scope:run(function()
		local parent = nil
		for k, value in props do
			if type(k) == "string" then
				if k == "Parent" then
					parent = value
				elseif k == "Tags" then
					bindTags(instance, value)
				elseif k == "Attributes" then
					bindAttributes(instance, value)
				elseif k == "Children" then
					for name, child in value do
						if type(name) == "string" and typeof(child) == "Instance" then
							child.Name = name
						end
					end
				else
					bindProperty(instance, k, value)
				end
			elseif type(k) == "table" and k[KEY] then
				bindSpecial(instance, k, value)
			end
		end

		local position = 0
		local children = props.Children
		if children then
			for _, child in children do
				position += 1
				bindChild(instance, child, position)
			end
		end
		for i = 1, #props do
			position += 1
			bindChild(instance, props[i], position)
		end

		local destroying = false
		connect(instance.Destroying, function()
			destroying = true
			scope:stop()
		end)
		if owned then
			Reactive.onCleanup(function()
				if not destroying then
					destroying = true
					instance:Destroy()
				end
			end)
		end

		if parent ~= nil then
			bindProperty(instance, "Parent", parent)
		end
	end)
	return instance
end

--[[
	Lucy.new "Frame" { ... } or Lucy.new("Frame", { ... }). Returns the Instance.
]]
function Element.new(className: string, props: { [any]: any }?): any
	if props ~= nil then
		return apply(Instance.new(className), props, true)
	end
	return function(p: { [any]: any }): Instance
		return apply(Instance.new(className), p or {}, true)
	end
end

--[[
	Lucy.hydrate(instance) { ... }: binds props, events and children onto an instance
	that already exists (built in Studio, cloned from a template). Not destroyed by Lucy.
]]
function Element.hydrate(instance: Instance, props: { [any]: any }?): any
	if props ~= nil then
		return apply(instance, props, false)
	end
	return function(p: { [any]: any }): Instance
		return apply(instance, p or {}, false)
	end
end

--[[
	Lucy.show(condition, render, fallback?): a child slot that renders `render()` while
	`condition` is truthy and `fallback()` otherwise. Only flips rebuild the branch.
]]
function Element.show(condition: any, render: () -> any, fallback: (() -> any)?): () -> any
	local truthy = Reactive.computed(function()
		return not not Reactive.toValue(condition)
	end)
	return function()
		if truthy() then
			return Reactive.untrack(render)
		elseif fallback then
			return Reactive.untrack(fallback)
		end
		return nil
	end
end

--[[
	Lucy.each(list, render, { key = fn }?): a child slot with one render per item.
	`list` is an array, a ref/getter of one, or a reactive list. Items are matched by
	key (the item itself by default), so instances for items that stay are kept and
	only moved. `render(item, index)` gets `index` as a ref.
]]
function Element.each(
	list: any,
	render: (item: any, index: () -> number) -> any,
	options: { key: ((item: any, index: number) -> any)? }?
): () -> any
	local keyOf = options and options.key
	local cache: { [any]: { any } } = {}

	Reactive.onCleanup(function()
		for _, entries in cache do
			for _, entry in entries do
				entry.scope:stop()
			end
		end
		table.clear(cache)
	end)

	return function()
		local items = Reactive.toValue(list)
		local nextCache: { [any]: { any } } = {}
		local out = {}
		for i = 1, #items do
			local item = items[i]
			local k = if keyOf then keyOf(item, i) else Reactive.toRaw(item)
			if k == nil then
				k = i
			end
			local entries = cache[k]
			local entry = entries and table.remove(entries, 1)
			if entry then
				entry.index(i)
			else
				local scope = Reactive.effectScope(true)
				local index = Reactive.ref(i)
				entry = { scope = scope, index = index }
				entry.nodes = Reactive.untrack(function()
					return collect(scope:run(render, item, index), {})
				end)
			end
			local bucket = nextCache[k]
			if bucket then
				table.insert(bucket, entry)
			else
				nextCache[k] = { entry }
			end
			for _, node in entry.nodes do
				table.insert(out, node)
			end
		end
		for _, entries in cache do
			for _, entry in entries do
				entry.scope:stop()
			end
		end
		cache = nextCache
		return out
	end
end

return Element
