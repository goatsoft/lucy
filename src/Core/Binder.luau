--!strict
--[[
	Binder: binds behaviour to every Instance carrying a CollectionService tag (ADR 0059).
	Works on the server and client and handles StreamingEnabled instances coming and going.

		local doors = Lucy.Binder.new("LockedDoor", function(door: Instance, maid: Lucy.Maid)
			if not door:IsA("BasePart") then
				return nil
			end
			local prompt = Instance.new("ProximityPrompt")
			prompt.Parent = door
			maid:give(prompt)
			return { door = door, prompt = prompt }
		end, { ancestor = workspace })

	Accepts either a function `fn(instance, maid) -> value?` or a class table with
	`.new(instance, maid) -> object`. If the returned table has a `destroy` or `Destroy`
	method, it is given to the instance's Maid automatically.

	Options:
		ancestor   only bind instances that are descendants of this Instance (e.g. workspace),
		           so tagged templates in ServerStorage or ReplicatedStorage are left alone
		warn       a custom warner (specs)
]]

local CollectionService = game:GetService("CollectionService")

local Maid = require(script.Parent.Maid)
local Signal = require(script.Parent.Signal)

export type BindFn = (instance: Instance, maid: Maid.Maid) -> ...any
export type BindClass = { new: (instance: Instance, maid: Maid.Maid) -> ...any, [any]: any }
export type BindTarget = BindFn | BindClass

export type Options = {
	ancestor: Instance?,
	warn: ((...any) -> ())?,
}

type Entry = {
	value: any,
	maid: Maid.Maid,
}

export type Binder = {
	tag: string,
	added: Signal.Signal,
	removed: Signal.Signal,
	get: (self: Binder, instance: Instance) -> any,
	has: (self: Binder, instance: Instance) -> boolean,
	all: (self: Binder) -> { [Instance]: any },
	count: (self: Binder) -> number,
	destroy: (self: Binder) -> (),
	Destroy: (self: Binder) -> (),
}

local Binder = {}
Binder.__index = Binder

local function resolveCtor(target: BindTarget): BindFn
	if type(target) == "function" then
		return target
	end
	if type(target) == "table" and type(target.new) == "function" then
		local ctor = target.new
		return function(instance: Instance, maid: Maid.Maid): any
			return ctor(instance, maid)
		end
	end
	error("[Lucy] Binder: expected a function or a table with .new(instance, maid)", 3)
end

local function isDestroyable(value: any): boolean
	return type(value) == "table" and (type(value.destroy) == "function" or type(value.Destroy) == "function")
end

function Binder.new(tag: string, target: BindTarget, options: Options?): Binder
	assert(type(tag) == "string" and #tag > 0, "[Lucy] Binder: tag must be a non-empty string")
	local ctor = resolveCtor(target)
	local ancestor = if options then options.ancestor else nil
	local warnFn: (...any) -> () = if options and options.warn then options.warn else warn

	local self: any = setmetatable({
		tag = tag,
		added = Signal.new(),
		removed = Signal.new(),
		_entries = {} :: { [Instance]: Entry },
		_ancestry = {} :: { [Instance]: RBXScriptConnection },
		_count = 0,
		_destroyed = false,
		_maid = Maid.new(),
	}, Binder)

	local function unbind(instance: Instance)
		local entry: Entry? = self._entries[instance]
		if not entry then
			return
		end
		self._entries[instance] = nil
		self._count -= 1
		self.removed:Fire(instance, entry.value)
		entry.maid:clean()
	end

	local function bind(instance: Instance)
		if self._destroyed or self._entries[instance] then
			return
		end
		if ancestor and not instance:IsDescendantOf(ancestor) then
			return
		end
		local maid = Maid.new()
		local ok, value = pcall(ctor, instance, maid)
		if not ok then
			maid:clean()
			warnFn(`[Lucy] Binder("{tag}"): failed to bind {instance:GetFullName()}: {tostring(value)}`)
			return
		end
		-- The instance may have been removed or destroyed while ctor ran.
		if self._destroyed or (ancestor and not instance:IsDescendantOf(ancestor)) then
			maid:clean()
			return
		end
		if value == nil and #(maid :: any) == 0 then
			return
		end
		if isDestroyable(value) then
			maid:give(value)
		end
		self._entries[instance] = { value = value, maid = maid }
		self._count += 1
		self.added:Fire(instance, value)
	end

	local function watch(instance: Instance)
		if self._destroyed then
			return
		end
		if ancestor then
			if not self._ancestry[instance] then
				self._ancestry[instance] = instance.AncestryChanged:Connect(function()
					if self._destroyed then
						return
					end
					if instance:IsDescendantOf(ancestor) then
						bind(instance)
					else
						unbind(instance)
					end
				end)
			end
			if instance:IsDescendantOf(ancestor) then
				bind(instance)
			end
		else
			bind(instance)
		end
	end

	local function unwatch(instance: Instance)
		local conn: RBXScriptConnection? = self._ancestry[instance]
		if conn then
			self._ancestry[instance] = nil
			conn:Disconnect()
		end
		unbind(instance)
	end

	self._maid:give(CollectionService:GetInstanceAddedSignal(tag):Connect(watch))
	self._maid:give(CollectionService:GetInstanceRemovedSignal(tag):Connect(unwatch))

	for _, instance in CollectionService:GetTagged(tag) do
		watch(instance)
	end

	return self :: Binder
end

function Binder.get(self: any, instance: Instance): any
	local entry: Entry? = self._entries[instance]
	return if entry then entry.value else nil
end

function Binder.has(self: any, instance: Instance): boolean
	return self._entries[instance] ~= nil
end

function Binder.all(self: any): { [Instance]: any }
	local out: { [Instance]: any } = {}
	for instance, entry in self._entries do
		out[instance] = entry.value
	end
	return out
end

function Binder.count(self: any): number
	return self._count
end

function Binder.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:clean()
	for instance, conn in self._ancestry do
		self._ancestry[instance] = nil
		conn:Disconnect()
	end
	for instance, entry in self._entries do
		self._entries[instance] = nil
		self._count -= 1
		self.removed:Fire(instance, entry.value)
		entry.maid:clean()
	end
	self.added:DisconnectAll()
	self.removed:DisconnectAll()
end

Binder.Destroy = Binder.destroy

return Binder
