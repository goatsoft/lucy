--!strict
--[[
	Component: the shared base every Lucy component is built on (ADR 0002, 0004).

	create(className, props, children)  instance factory (Tags, Attributes, Children)
	setVariant(inst, base, key, value)  "ui-button-variant-outline" style tags for rules
	setFlag(inst, tag, on)              boolean tags such as "ui-disabled"
	mount(spec, props)                  state-bound handle, see below

	A mounted component keeps its stateful props in AppState at "ui.<id>" (ADR 0004,
	0017). The app controls it by writing there; the component's render binds to
	those keys, so only what changed is touched (ADR 0018).

		local spec = {                     -- one per kind, shared by every mount
			kind = "switch",
			defaults = { checked = false, ... }, -- the keys that live in state
			rules = Switch.rules,          -- registered on the theme once per kind
			render = function(h)           -- runs once per mount, in the component's scope
				local checked = h:ref("checked")
				Lucy.watch(checked, function(on) ... end) -- side effects only
				return Lucy.new "Frame" { Tags = { "ui-switch", ["ui-checked"] = checked } }
			end,
		}
		local handle = Component.mount(spec, props) -- props may include app, id, Parent, persist
		handle:set("checked", true) ; handle:set({ label = "Go" }) ; handle:get("checked")
		handle:destroy()

	The rule: derive with computed, bind with refs and getters, share logic with
	composables (Lucy.useDensity ...), and keep Lucy.watch for side effects such as
	tweens and callbacks. Everything render creates is owned by the component, and
	elements made in render share its scope.

	Reactive props: any state key may be given a ref, a computed or a getter
	function instead of a plain value. A writable source (a ref, a computed with
	{ get, set }, or app.state:ref) is bound to the key: any write to the key, by
	the component, the app or the source's owner, is a write to the source, so
	`checked = isOn` keeps a Switch and a ref in step. A read-only source is a
	derived key: it follows the source, a local write overrides it, and the
	source's next change wins. A component created inside an effect, a scope or an
	`each` item is destroyed when that owner stops.

	A spec built once and shared costs nothing per mount; render reads per-mount
	props (callbacks and the like) from `h.props`. `mount({ ..., props = props })`
	still works.
]]

local CollectionService = game:GetService("CollectionService")

local Context = require(script.Parent.Context)
local Maid = require(script.Parent.Maid)
local Reactive = require(script.Parent.Reactive)
local Signal = require(script.Parent.Signal)
local Theme = require(script.Parent.Theme)
local UiEvents = require(script.Parent.UiEvents)

export type Rule = Theme.Rule
export type Props = { [string]: any }
export type State = { [string]: any }

local Component = {}

local SPECIAL = { Tags = true, Attributes = true, Children = true, Parent = true }

function Component.create(className: string, props: { [string]: any }?, children: { [any]: Instance }?): any
	local instance = Instance.new(className)
	local p: { [string]: any } = props or {}
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

-- State keys whose prop is a ref, computed or getter: key -> source. Nil if none.
local function pickSources(defaults: { [string]: any }, props: { [string]: any }): { [string]: any }?
	local sources: { [string]: any }? = nil
	for key in defaults do
		local value = props[key]
		if type(value) == "function" then
			if sources then
				sources[key] = value
			else
				sources = { [key] = value }
			end
		end
	end
	return sources
end

local Handle = {}
Handle.__index = Handle

-- Components may keep their own parts on the handle too, hence the indexer.
type HandleFields = {
	app: any,
	kind: string,
	id: string,
	path: string,
	segments: { any }, -- `path`, split once
	refs: { [string]: any } | false, -- h:ref(key), one per key; made on the first
	props: { [string]: any },
	maid: Maid.Maid,
	destroyed: boolean,
	Instance: any,
	scope: Reactive.Scope?,
	[string]: any,
}
export type Handle = typeof(setmetatable({} :: HandleFields, Handle))

-- One key's value, or the whole state as a frozen snapshot. A key read allocates nothing.
function Handle.get(self: Handle, key: string?): any
	if key == nil then
		return self.app.state:_read(self.segments)
	end
	return self.app.state:_readKey(self.segments, key)
end

--[[
	h:ref(key): a writable ref onto one of the component's state keys. Reading it
	tracks that key's own source (no node of its own); writing it writes the store,
	so bound refs and store subscribers see the write. One per key.
]]
function Handle.ref(self: Handle, key: string): Reactive.Ref<any>
	local current: { [string]: any }? = self.refs or nil
	local refs: { [string]: any }
	if current then
		local existing = current[key]
		if existing then
			return existing
		end
		refs = current
	else
		refs = {}
		self.refs = refs
	end
	local state = self.app.state
	local segments = self.segments
	-- One closure per ref, and writes build nothing.
	local ref = Reactive._markAccessor(function(...: any): any
		if select("#", ...) == 0 then
			return (state:_trackedKey(segments, key))
		end
		state:_writeKey(segments, key, (...))
		return nil
	end)
	refs[key] = ref
	return ref
end

-- set(key, value) writes one key (allocates nothing); set(patch) merges a table.
function Handle.set(self: Handle, patch: { [string]: any } | string, value: any?)
	if type(patch) == "string" then
		self.app.state:_writeKey(self.segments, patch, value)
	else
		self.app.state:_write(self.segments, patch, true)
	end
end

function Handle.destroy(self: Handle)
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.app:unregisterHandle(self)
	local scope = self.scope
	if scope then
		scope:stop() -- first: render's bindings and watchers end before anything else
	end
	self.maid:clean()
	if self.Instance then
		self.Instance:Destroy()
	end
	if not self.props.persist then
		self.app.state:remove(self.path)
	end
end
Handle.Destroy = Handle.destroy

--[[
	A focus ring round one part of a control (a radio's circle, a checkbox's box,
	a switch's track), for rows where ringing the whole row would wrap the label
	too. Parent it to the part and tag the row "ui-ring-host": the row's own ring
	is then hidden and this one shows while the row has the focus ring. Styled
	with the same tokens as the base ring (Theme).
]]
function Component.partRing(app: any): Frame
	local gap = 2 * (tonumber(app.theme:resolve("StrokeThin")) or 1)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, gap, 1, gap)
	ring.BackgroundTransparency = 1
	ring.Selectable = false
	ring:AddTag("ui-part-ring")
	local corner = Instance.new("UICorner")
	corner:AddTag("ui-part-ring-corner")
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke:AddTag("ui-part-ring-stroke")
	stroke.Parent = ring
	return ring
end

--[[
	Gives a handle the click path every pressable component shares:
	handle.Activated (a Signal) and handle:click(). A click is ignored while the
	component is disabled or within 50 ms of the last one (keyboard Enter can
	arrive twice: the engine's activation and InputManager's). It calls
	props.onClick, fires Activated and reports "activate" for Lucy.useUiSound.
]]
function Component.clickable(handle: any)
	local activated = Signal.new()
	handle.Activated = activated
	handle.maid:give(function()
		activated:DisconnectAll()
	end)
	local lastClick = -math.huge
	function handle.click(h)
		if h.destroyed or h:get("disabled") then
			return
		end
		local now = os.clock()
		if now - lastClick < 0.05 then
			return
		end
		lastClick = now
		local onClick = h.props.onClick
		if onClick then
			onClick(h)
		end
		activated:Fire(h)
		h:emit("activate")
	end
end

-- Reports a moment (activate, toggle, select, open, close) for Lucy.useUiSound.
function Handle.emit(self: Handle, event: string, value: any?)
	UiEvents.emit(self, event, value)
end

export type Spec = {
	kind: string,
	props: Props?,
	defaults: State?,
	rules: { Rule }?,
	ruleKey: string?,
	render: (handle: Handle) -> any,
	mounted: ((handle: Handle) -> ())?,
}

function Component.mount(spec: Spec, props: Props?): Handle
	local props: Props = props or spec.props or {}
	local app = Component.resolveApp(props)
	local kind: string = spec.kind

	if spec.rules then
		app.theme:addRules(spec.ruleKey or kind, spec.rules)
	end

	local id = props.id or app:nextId(kind)
	if string.find(id, ".", 1, true) then
		error(`[Lucy] component id "{id}" must not contain "."`, 2)
	end

	local path = "ui." .. id
	local fields: HandleFields = {
		app = app,
		kind = kind,
		id = id,
		path = path,
		segments = app.state:_segments(path),
		refs = false,
		props = props,
		maid = Maid.new(),
		destroyed = false,
		Instance = nil,
		scope = nil,
	}
	local handle: Handle = setmetatable(fields, Handle)

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
	if sources then
		for key, source in sources do
			initial[key] = Reactive.peek(source)
		end
	end
	app.state:_place(handle.segments, initial) -- the store keeps `initial` itself

	-- Writable sources are bound to their key (ADR 0017): a write to the key writes
	-- the source within the same store write. Unbound on destroy; the source lives on.
	local segments = handle.segments
	if sources then
		for key, source in sources do
			if Reactive.isWritable(source) then
				handle.maid:give(app.state:_alias(segments, key, source))
			end
		end
	end

	-- Ownership. The scope belongs to whatever effect, scope or `each` item is
	-- running now; stopping it destroys the component, and destroying the component
	-- stops the scope. Render runs inside it, so everything render creates
	-- (bindings, computeds, watchers, composables) is the component's.
	local scope = Reactive.effectScope()
	handle.scope = scope
	local okRender, rendered = pcall(scope.run, scope, spec.render, handle)
	if not okRender then
		scope:stop()
		handle.maid:clean()
		error(rendered, 0)
	end
	local root = rendered
	handle.Instance = root
	root.Name = props.name or root.Name ~= root.ClassName and root.Name or kind
	if props.layoutOrder then
		root.LayoutOrder = props.layoutOrder
	end
	root:SetAttribute("LucyId", id)
	Component.claimSelection(app, root)
	app:registerHandle(handle)
	scope:onCleanup(function()
		handle:destroy()
	end)

	-- Each source drives its key; for a bound source this is the only copy, and the
	-- store skips equal values, so nothing ping-pongs.
	if sources then
		scope:run(function()
			for key, source in sources do
				Reactive._effect(function()
					local value = Reactive.toValue(source)
					if not handle.destroyed and app.state:_readKey(segments, key) ~= value then
						Reactive._untracked(handle.set, handle, key, value)
					end
				end)
			end
		end)
	end

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
