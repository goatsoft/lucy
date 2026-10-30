--!strict
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

	Lifetime: an element created inside an owner (a component's render, an effect, a
	show branch, an each item, an effectScope) shares that owner's scope: its
	bindings are the owner's, and when the owner stops, the bindings stop first and
	then the element is destroyed. Destroying such an element yourself does not stop
	its bindings; stop the owner instead (a show or each slot does that for you).
	An element created with no owner gets a scope of its own, stopped when the
	instance is destroyed by anyone. Hydrated instances are never destroyed by Lucy,
	only unbound, and always get their own scope.
]]

local Reactive = require(script.Parent.Reactive)

local Element = {}

local KEY = "__lucyKey"
local ORDER_SLOT = 100000 -- LayoutOrder room per child position, for show/each slots
local CALLBACKS = { OnInvoke = true, OnClientInvoke = true, OnServerInvoke = true }

local ordered: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- each slot -> the function that stops its rows, so the host element can stop them
-- before destroying itself (rather than its Destroy cascading into live rows).
local slotCleanups: { [any]: () -> () } = setmetatable({}, { __mode = "k" }) :: any
-- element instance -> its binding scope; an owned parent stops static children first.
-- Strong on purpose (the scope reaches the instance through its bindings, so weak keys
-- would never clear); each entry is removed when its scope stops.
local scopes: { [Instance]: any } = {}
-- owner -> the elements created in it this run (ADR 0018). One list and one cleanup
-- per owner run instead of a scope and a Destroying hook per element. Strong; each
-- entry is removed by the owner's cleanup.
local groups: { [any]: { Instance } } = {}

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

local function setProperty(instance: any, property: string, value: any)
	instance[property] = value
end

-- No closure per write: bindings call this on every change.
local function assign(instance: Instance, property: string, value: any)
	local ok: boolean, err: any = pcall(setProperty :: any, instance, property, value)
	if not ok then
		error(`[Lucy] {describe(instance, property)}: {err}`, 0)
	end
end

local function bindProperty(instance: Instance, property: string, value: any)
	if type(value) == "function" and not CALLBACKS[property] then
		Reactive._effect(function()
			assign(instance, property, value())
		end)
	else
		assign(instance, property, value)
	end
end

--[[
	Getter bindings (properties and keyed tags) are gathered while `bind` reads the
	props, then bound once per getter: properties and tags that share a getter run it
	once, in one effect (Button's Interactable and Selectable read one getter). The
	three arrays are a stack shared by every bind: a getter that makes elements while
	it runs binds above the entries still being bound, then pops its own.
]]
local pendingGetter: { any } = {}
local pendingName: { string } = {}
local pendingTag: { boolean } = {}
local pendingTop = 0

local function defer(getter: any, name: string, isTag: boolean)
	local top = pendingTop + 1
	pendingTop = top
	pendingGetter[top] = getter
	pendingName[top] = name
	pendingTag[top] = isTag
end

local function setTag(instance: Instance, tag: string, on: any)
	if on then
		instance:AddTag(tag)
	else
		instance:RemoveTag(tag)
	end
end

local function bindTag(instance: Instance, tag: string, getter: any)
	Reactive._effect(function()
		setTag(instance, tag, getter())
	end)
end

-- One effect for every property and tag bound to `getter`.
local function bindShared(instance: Instance, getter: any, properties: { string }?, tags: { string }?)
	Reactive._effect(function()
		local value = getter()
		if properties then
			for _, property in properties do
				assign(instance, property, value)
			end
		end
		if tags then
			for _, tag in tags do
				setTag(instance, tag, value)
			end
		end
	end)
end

-- Binds the entries above `from`, then pops them.
local function bindPending(instance: Instance, from: number)
	local top = pendingTop
	for i = from + 1, top do
		local getter = pendingGetter[i]
		if getter then
			local shared = false
			for j = i + 1, top do
				if pendingGetter[j] == getter then
					shared = true
					break
				end
			end
			if not shared then
				if pendingTag[i] then
					bindTag(instance, pendingName[i], getter)
				else
					bindProperty(instance, pendingName[i], getter)
				end
			else
				local properties: { string }? = nil
				local tags: { string }? = nil
				for j = i, top do
					if pendingGetter[j] == getter then
						pendingGetter[j] = false
						local name = pendingName[j]
						if pendingTag[j] then
							local list: { string } = tags or {}
							tags = list
							table.insert(list, name)
						else
							local list: { string } = properties or {}
							properties = list
							table.insert(list, name)
						end
					end
				end
				bindShared(instance, getter, properties, tags)
			end
		end
	end
	for i = from + 1, top do
		pendingGetter[i] = nil
		pendingName[i] = nil
		pendingTag[i] = nil
	end
	pendingTop = from
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
		-- Two sets that swap each run and are cleared, never rebuilt, so a change builds
		-- no tables. The second one is made on the first change, not at mount.
		local applied: { [string]: boolean }? = nil
		local spare: { [string]: boolean }? = nil
		Reactive._effect(function()
			local want: { [string]: boolean } = spare or {}
			table.clear(want)
			collectTags(tags(), want)
			local had = applied
			if had then
				for tag in had do
					if not want[tag] then
						instance:RemoveTag(tag)
					end
				end
				for tag in want do
					if not had[tag] then
						instance:AddTag(tag)
					end
				end
			else
				for tag in want do
					instance:AddTag(tag)
				end
			end
			spare = had
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
			defer(v, k, true)
		elseif v then
			instance:AddTag(k)
		end
	end
end

local function bindAttributes(instance: Instance, attributes: { [string]: any })
	for name, value in attributes do
		if type(value) == "function" then
			Reactive._effect(function()
				instance:SetAttribute(name, value())
			end)
		else
			instance:SetAttribute(name, value)
		end
	end
end

local function connect(signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(handler)
	Reactive.onCleanup(function()
		connection:Disconnect()
	end)
	return connection
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

local function bindChild(instance: Instance, child: any, position: number, owned: boolean)
	local base = position * ORDER_SLOT
	if type(child) ~= "function" then
		for j, item in collect(child, {}) do
			order(item, base + j)
			item.Parent = instance
			local childScope = owned and scopes[item]
			if childScope then
				Reactive.onCleanup(function()
					childScope:stop()
				end)
			end
		end
		return
	end
	-- A reactive slot: show, each, or any getter returning children.
	local stopRows = slotCleanups[child]
	if stopRows then
		Reactive.onCleanup(stopRows)
	end
	local current: { Instance } = {}
	Reactive._effect(function()
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

-- Reads the props: static values are set now, getters are gathered (see defer).
-- Returns the Parent prop, which is bound last.
local function readProps(instance: Instance, props: { [any]: any }): any
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
			elseif type(value) == "function" and not CALLBACKS[k] then
				defer(value, k, false)
			else
				assign(instance, k, value)
			end
		elseif type(k) == "table" and k[KEY] then
			bindSpecial(instance, k, value)
		end
	end
	return parent
end

local function bind(instance: Instance, props: { [any]: any }, owned: boolean)
	local from = pendingTop
	local ok: boolean, parent: any = pcall(readProps, instance, props)
	if not ok then
		-- Pop what was gathered before the error, then report it as before.
		for i = from + 1, pendingTop do
			pendingGetter[i] = nil
			pendingName[i] = nil
			pendingTag[i] = nil
		end
		pendingTop = from
		error(parent, 0)
	end
	bindPending(instance, from)

	local position = 0
	local children = props.Children
	if children then
		for _, child in children do
			position += 1
			bindChild(instance, child, position, owned)
		end
	end
	for i = 1, #props do
		position += 1
		bindChild(instance, props[i], position, owned)
	end

	if parent ~= nil then
		bindProperty(instance, "Parent", parent)
	end
end

-- An element in an owner: its bindings are the owner's. The owner's first element
-- registers one cleanup, before any binding so it runs after them all (cleanups run
-- in reverse): bindings and slot rows stop, then every element of that run is
-- destroyed (children made before their parent go first; that is harmless).
local function grouped(owner: any, instance: Instance, props: { [any]: any }): Instance
	local items = groups[owner]
	if items == nil then
		local list: { Instance } = {}
		items = list
		groups[owner] = list
		Reactive.onCleanup(function()
			groups[owner] = nil
			for i = #list, 1, -1 do
				list[i]:Destroy()
			end
		end)
	end
	table.insert(items :: { Instance }, instance)
	bind(instance, props, true)
	return instance
end

local function apply(instance: Instance, props: { [any]: any }, owned: boolean): Instance
	if owned then
		local owner = Reactive._owner()
		if owner ~= nil then
			return grouped(owner, instance, props)
		end
	end
	local scope = Reactive.effectScope()
	scopes[instance] = scope
	-- Destroying from outside stops the scope. One cleanup, registered before any
	-- binding so it runs last (cleanups run in reverse): bindings and slot rows stop
	-- before the instance is destroyed.
	local destroying = false
	local onDestroying = instance.Destroying:Connect(function()
		destroying = true
		scope:stop()
	end)
	scope:onCleanup(function()
		scopes[instance] = nil
		-- Disconnect first: a live Destroying handler costs a resumed thread (about
		-- 1.2 KB) per instance, only to stop a scope already stopping.
		onDestroying:Disconnect()
		if owned and not destroying then
			destroying = true
			instance:Destroy()
		end
	end)
	scope:run(bind, instance, props, owned)
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

	local function stopAll()
		for _, entries in cache do
			for _, entry in entries do
				entry.scope:stop()
			end
		end
		table.clear(cache)
	end
	Reactive.onCleanup(stopAll)

	local slot = function()
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
			local entry: any = entries and table.remove(entries, 1)
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
	slotCleanups[slot] = stopAll
	return slot
end

return Element
