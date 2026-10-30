--[[
	Component: the shared base every Lucy component is built on (ADR 0002, 0004).

	create(className, props, children)  instance factory (Tags, Attributes, Children)
	setVariant(inst, base, key, value)  "ui-button-variant-outline" style tags for rules
	setFlag(inst, tag, on)              boolean tags such as "ui-disabled"
	mount(spec)                         state-bound handle, see below

	A mounted component keeps its stateful props in AppState at "ui.<id>". The app
	controls it by writing there; the component re-renders through `update`.

		local handle = Component.mount({
			kind = "button",
			props = props,                 -- may include app, id, Parent, persist
			defaults = { text = "", ... }, -- the keys that live in state
			rules = Button.rules,          -- registered on the theme once per kind
			render = function(handle) return rootInstance end,
			update = function(handle, state, previous) ... end,
		})
		handle:set({ text = "Go" }) ; handle:get("text") ; handle:destroy()

	Reactive props: any state key may be given a ref, a computed or a getter
	function instead of a plain value. The component follows it, writing each new
	value to "ui.<id>" as usual. Writable sources (a ref, or a computed with
	{ get, set }) are two-way: when the component or the app changes that key, the
	source is written too, so `checked = isOn` keeps a Switch and a ref in step.
	A read-only source wins on its next change. A component created inside an
	effect, a scope or an `each` item is destroyed when that owner stops.
]]

local CollectionService = game:GetService("CollectionService")

local Context = require(script.Parent.Context)
local Maid = require(script.Parent.Maid)
local Reactive = require(script.Parent.Reactive)

local Component = {}

local SPECIAL = { Tags = true, Attributes = true, Children = true, Parent = true }

function Component.create(className: string, props: { [string]: any }?, children: { [any]: Instance }?): any
	local instance = Instance.new(className)
	local p = props or {}
	for key, value in p do
		if not SPECIAL[key] then
			(instance :: any)[key] = value
		end
	end
	if p.Tags then
		for _, tag in p.Tags do
			CollectionService:AddTag(instance, tag)
		end
	end
	if p.Attributes then
		for key, value in p.Attributes do
			instance:SetAttribute(key, value)
		end
	end
	local function adopt(list)
		for key, child in list do
			if type(key) == "string" then
				child.Name = key
			end
			child.Parent = instance
		end
	end
	if p.Children then
		adopt(p.Children)
	end
	if children then
		adopt(children)
	end
	if p.Parent then
		instance.Parent = p.Parent
	end
	return instance
end

-- Tag `inst` with "<base>-<key>-<value>", removing any previous value for that key.
function Component.setVariant(instance: Instance, base: string, key: string, value: string?)
	local prefix = `{base}-{key}-`
	for _, tag in instance:GetTags() do
		if string.sub(tag, 1, #prefix) == prefix then
			instance:RemoveTag(tag)
		end
	end
	if value ~= nil and value ~= "" then
		instance:AddTag(prefix .. value)
	end
end

function Component.setFlag(instance: Instance, tag: string, on: boolean?)
	if on then
		instance:AddTag(tag)
	else
		instance:RemoveTag(tag)
	end
end

--[[
	Parents children into `parent`. Each item may be an Instance, a component
	handle (anything with .Instance), a function(parent) or an array of those.
	Array items get ascending LayoutOrder so list layouts keep declaration order.
]]
function Component.adopt(parent: Instance, items: any, startOrder: number?): number
	local order = startOrder or 0
	if items == nil then
		return order
	end
	local kind = typeof(items)
	if kind == "function" then
		items(parent)
		return order
	end
	if kind == "Instance" then
		order += 1
		if items:IsA("GuiObject") and items.LayoutOrder == 0 then
			items.LayoutOrder = order
		end
		items.Parent = parent
		return order
	end
	if kind == "table" then
		if typeof(items.Instance) == "Instance" then
			return Component.adopt(parent, items.Instance, order)
		end
		for _, item in ipairs(items) do
			order = Component.adopt(parent, item, order)
		end
	end
	return order
end

-- A transparent Frame for structure (headers, bodies, rows). Never styled by rules.
function Component.box(props: { [string]: any }?): Frame
	local p = table.clone(props or {})
	if p.BackgroundTransparency == nil then
		p.BackgroundTransparency = 1
	end
	if p.BorderSizePixel == nil then
		p.BorderSizePixel = 0
	end
	if p.Size == nil then
		p.Size = UDim2.fromScale(1, 0)
		p.AutomaticSize = p.AutomaticSize or Enum.AutomaticSize.Y
	end
	return Component.create("Frame", p)
end

-- A UIListLayout with sensible defaults.
function Component.list(props: { [string]: any }?): UIListLayout
	local p = table.clone(props or {})
	p.SortOrder = p.SortOrder or Enum.SortOrder.LayoutOrder
	return Component.create("UIListLayout", p)
end

-- Pixel value of a spacing token (UDim) or a raw number, for layout padding.
function Component.space(app: any, value: any, fallback: number?): UDim
	if typeof(value) == "UDim" then
		return value
	end
	if type(value) == "number" then
		return UDim.new(0, value)
	end
	if type(value) == "string" then
		local resolved = app.theme:resolve(value)
		if typeof(resolved) == "UDim" then
			return resolved
		end
	end
	return UDim.new(0, fallback or 0)
end

-- Pixel height of a control token in the active density (ControlSm/Md/Lg/Icon).
function Component.metric(app: any, token: string): number
	local value = app.theme:resolve(token)
	if typeof(value) == "UDim2" then
		return value.Y.Offset
	end
	return if type(value) == "number" then value else 0
end

-- Runs fn now and whenever the density (default / touch / tv) changes.
function Component.onDensity(handle: any, fn: () -> ())
	fn()
	handle.maid:give(handle.app.state:subscribe("density", function()
		fn()
	end))
end

--[[
	Takes over gamepad/keyboard selection visuals for `object` and its selectable
	descendants: the engine's white ring is replaced by the app's blank image and
	our themed ".ui-focus-visible" ring is drawn instead (see InputManager).
]]
function Component.claimSelection(app: any, object: Instance)
	local function claim(target: Instance)
		if target:IsA("GuiObject") then
			target.SelectionImageObject = app.selectionImage
		end
	end
	claim(object)
	for _, descendant in object:GetDescendants() do
		claim(descendant)
	end
end

function Component.resolveApp(props: { [string]: any }?): any
	local app = (props and props.app) or Context.getCurrent()
	if not app then
		error("[Lucy] no App: pass `app` in props or create one with App.new()", 3)
	end
	return app
end

local function pickState(defaults: { [string]: any }, props: { [string]: any }): { [string]: any }
	local state = table.clone(defaults)
	for key in defaults do
		local value = props[key]
		if value ~= nil and type(value) ~= "function" then
			state[key] = value
		end
	end
	return state
end

-- State keys whose prop is a ref, computed or getter: key -> source.
local function pickSources(defaults: { [string]: any }, props: { [string]: any }): { [string]: any }
	local sources = {}
	for key in defaults do
		if type(props[key]) == "function" then
			sources[key] = props[key]
		end
	end
	return sources
end

local Handle = {}
Handle.__index = Handle

function Handle:get(key: string?): any
	local state = self.app.state:get(self.path)
	if key == nil then
		return state
	end
	return if state then state[key] else nil
end

function Handle:set(patch: { [string]: any })
	self.app.state:merge(self.path, patch)
end

function Handle:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.app:unregisterHandle(self)
	self.maid:clean()
	if self.Instance then
		self.Instance:Destroy()
	end
	if not self.props.persist then
		self.app.state:remove(self.path)
	end
end
Handle.Destroy = Handle.destroy

function Component.mount(spec: { [string]: any })
	local props = spec.props or {}
	local app = Component.resolveApp(props)
	local kind: string = spec.kind

	if spec.rules then
		app.theme:addRules(spec.ruleKey or kind, spec.rules)
	end

	local id = props.id or app:nextId(kind)
	if string.find(id, ".", 1, true) then
		error(`[Lucy] component id "{id}" must not contain "."`, 2)
	end

	local handle = setmetatable({
		app = app,
		kind = kind,
		id = id,
		path = "ui." .. id,
		props = props,
		maid = Maid.new(),
		destroyed = false,
	}, Handle)

	-- Seed state: defaults <- props, then anything the app already set wins,
	-- except keys bound to a reactive source, which always start from the source.
	local defaults = spec.defaults or {}
	local sources = pickSources(defaults, props)
	local initial = pickState(defaults, props)
	local existing = app.state:get(handle.path)
	if type(existing) == "table" then
		for key, value in existing do
			initial[key] = value
		end
	end
	for key, source in sources do
		initial[key] = Reactive.peek(source)
	end
	app.state:set(handle.path, initial)

	local root = spec.render(handle)
	handle.Instance = root
	root.Name = props.name or root.Name ~= root.ClassName and root.Name or kind
	if props.layoutOrder then
		root.LayoutOrder = props.layoutOrder
	end
	root:SetAttribute("LucyId", id)
	Component.claimSelection(app, root)
	app:registerHandle(handle)

	local previous = nil
	local function apply(state)
		if handle.destroyed or state == nil then
			return
		end
		if spec.update then
			spec.update(handle, state, previous)
		end
		local before = previous
		previous = state
		-- Two-way: a state change on a key bound to a writable source writes it back.
		if before then
			for key, source in sources do
				local value = state[key]
				if value ~= nil and value ~= before[key] and Reactive.isWritable(source) then
					if Reactive.peek(source) ~= value then
						source(value)
					end
				end
			end
		end
	end
	apply(app.state:get(handle.path))
	handle.maid:give(app.state:subscribe(handle.path, apply))

	-- Ownership and reactive props. The scope belongs to whatever effect, scope or
	-- `each` item is running now; stopping it destroys the component, and
	-- destroying the component stops the scope.
	local scope = Reactive.effectScope()
	handle.scope = scope
	scope:onCleanup(function()
		handle:destroy()
	end)
	handle.maid:give(function()
		scope:stop()
	end)
	scope:run(function()
		for key, source in sources do
			Reactive.watchEffect(function()
				local value = Reactive.toValue(source)
				Reactive.untrack(function()
					if not handle.destroyed and handle:get(key) ~= value then
						handle:set({ [key] = value })
					end
				end)
			end)
		end
	end)

	local parent = props.Parent or props.parent
	if parent then
		root.Parent = parent
	end

	if spec.mounted then
		spec.mounted(handle)
	end
	return handle
end

return Component
