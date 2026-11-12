--!strict
--[[
	Aura: an effect worn in the world, on a character or at a point: a glow that grows with a
	player's rank, wings bought for half an hour, sparks round whoever is on a streak. One base
	with the plumbing, and aura types that only build and animate (ADR 0046).

	One aura, on its own:

		local aura = Lucy.Aura.new({
			type = "glow",               -- a registered type (built in: glow)
			character = model,           -- worn on a character, or
			position = Vector3.new(...), -- stood at a point
			-- and the type's own options, e.g. glow: token, size, sparks
		})
		aura:finish()                    -- plays the closing, then goes
		aura:destroy()                   -- goes at once

	Every aura in the store, on whoever wears it (the usual way, on the client):

		Lucy.Aura.follow(app, {
			resolve = function(id) return characterOf(id) end, -- default: the player with that UserId
			hidden = onStage,           -- a ref or getter: hides every aura while true
		})

	and on the server, who wears what (every App sees it at server.auras):

		Lucy.Aura.wear(server, player.UserId, "glow", { options = { token = "Warning" }, seconds = 1800 })
		Lucy.Aura.take(server, player.UserId, "glow")

	The store holds shared.auras.<id>.<type> = { options, untilTime } on the server, so each App
	reads server.auras.<id>.<type>. A timed aura closes by itself when the server's clock passes
	untilTime. Lucy only draws: why someone wears an aura, and for how long, is the game's.

	The base mounts each aura (it comes back after a respawn), runs every aura in a follower from
	one frame driver, fades auras with distance from the camera and stops the farthest past the
	budget (max), follows reduced motion (the opening jumps to its end and loops hold still), and
	leaves nothing behind when an aura, its character or the App goes.

	A type: Aura.register(name, {
		intro = 0.6,          -- seconds the opening takes
		outro = 0.4,          -- seconds the closing takes
		loop = true,          -- keeps running after the opening (ctx.elapsed advances)
		defaults = { ... },   -- the type's options
		build = function(ctx) end,
	})
	build makes the aura's parts once and binds them to the context:
		ctx.root              a Model in the character (or workspace, for a point) for parts
		ctx.character         the character, or nil at a point
		ctx.attachment(name)  an attachment of the aura's own, where the character's attachment
		                      of that name is (RootAttachment when it has none); at a point,
		                      the point. Put emitters, beams and lights on these
		ctx.part(name)        the character's part of that name, to weld a model to
		ctx.intro()           seconds into the opening (stops at intro)
		ctx.elapsed()         seconds running (loop types only)
		ctx.outro()           seconds into the closing (0 until it closes)
		ctx.strength()        0 to 1, from distance and the budget; at 0 the aura is off
		ctx.reducedMotion()   true when the player asked for less motion
		ctx.option(name)      an option, or the type's default
		ctx.color(token)      a theme colour, e.g. ctx.color("Primary")
		ctx.animate(rig, id)  plays an animation on a rigged model (wings), looped; held still
		                      with reduced motion, stopped with the aura
		ctx.give(item)        cleaned up with the aura (a connection, a stop function)
	The getters are reactive: bind properties with Lucy.new or follow them in a watchEffect.
]]

local Players = game:GetService("Players")

local Animate = require(script.Parent.Animate)
local Maid = require(script.Parent.Maid)
local Preferences = require(script.Parent.Preferences)
local Reactive = require(script.Parent.Reactive)
local Signal = require(script.Parent.Signal)

local Aura = {}

export type Context = {
	app: any,
	root: Model,
	character: Model?,
	attachment: (name: string) -> Attachment,
	part: (name: string) -> BasePart?,
	intro: () -> number,
	elapsed: () -> number,
	outro: () -> number,
	strength: () -> number,
	reducedMotion: () -> boolean,
	option: (name: string) -> any,
	color: (token: string) -> Color3,
	animate: (rig: Instance, id: string) -> AnimationTrack?,
	give: (item: any) -> any,
}

export type Definition = {
	intro: number?,
	outro: number?,
	loop: boolean?,
	defaults: { [string]: any }?,
	build: (ctx: Context) -> (),
}

Aura.types = {} :: { [string]: Definition }

-- Adds an aura type (or replaces one of the same name)
function Aura.register(name: string, definition: Definition)
	assert(type(name) == "string" and name ~= "", "[Lucy] an aura type needs a name")
	assert(
		type(definition) == "table" and type(definition.build) == "function",
		`[Lucy] aura type "{name}" needs a build`
	)
	Aura.types[name] = definition
end

local function definitionOf(name: any): Definition
	local definition = if type(name) == "string" then Aura.types[name] else nil
	if not definition then
		local known = {}
		for key in Aura.types do
			table.insert(known, key)
		end
		table.sort(known)
		error(`[Lucy] unknown Aura type "{tostring(name)}" (known: {table.concat(known, ", ")})`, 0)
	end
	return definition
end

local function currentApp(): any
	local App = (script.Parent :: any).App
	return (require(App) :: any).current()
end

-- Where an aura is, for distance: the character's root part, or its point.
local function anchorOf(character: Model?, point: Vector3?): Vector3?
	if character then
		local part = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
		if part and part:IsA("BasePart") then
			return part.Position
		end
		return nil
	end
	return point
end

local Handle = {}
Handle.__index = Handle

export type Handle = typeof(setmetatable(
	{} :: {
		type: string,
		root: Model,
		character: Model?,
		point: Vector3?,
		strength: number,
		finishing: boolean,
		destroyed: boolean,
		done: Signal.Signal,
		_definition: Definition,
		_maid: any,
		_scope: any,
		_attachments: { { attachment: Attachment, parent: Instance } },
		_tracks: { AnimationTrack },
		_intro: any,
		_elapsed: any,
		_outro: any,
		_strength: any,
		_reduced: any,
		_stopDrive: (() -> ())?,
	},
	Handle
))

--[[
	Aura.new(props): one aura, driven by itself. props:
		type        the aura type (required)
		character   the Model it is worn on, or
		position    the Vector3 it stands at
		app         the App whose theme it uses and with which it goes (Lucy.App.current())
		drive       false to leave stepping to a follower
		and the type's own options.
]]
function Aura.new(props: { [string]: any }): Handle
	local definition = definitionOf(props.type)
	local character: Model? = props.character
	local point: Vector3? = props.position
	assert(character ~= nil or typeof(point) == "Vector3", "[Lucy] an aura needs a character or a position")
	local app = props.app or currentApp()
	local defaults = definition.defaults or {}
	local options = props.options or props

	local self = setmetatable({
		type = props.type,
		character = character,
		point = point,
		strength = 1,
		finishing = false,
		destroyed = false,
		done = Signal.new(),
		_definition = definition,
		_maid = Maid.new(),
		_attachments = {},
		_tracks = {},
		_intro = Reactive.ref(0),
		_elapsed = Reactive.ref(0),
		_outro = Reactive.ref(0),
		_strength = Reactive.ref(1),
		_reduced = Reactive.ref(Preferences.reducedMotion()),
	}, Handle) :: any

	local root = Instance.new("Model")
	root.Name = "LucyAura_" .. props.type
	self.root = root

	-- At a point: one anchored, invisible part holds the point's attachment.
	local holder: BasePart? = nil
	if not character then
		local part = Instance.new("Part")
		part.Name = "Point"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one * 0.2
		part.CFrame = CFrame.new(point :: Vector3)
		part.Parent = root
		holder = part
	end

	local ctx: Context = {
		app = app,
		root = root,
		character = character,
		attachment = function(name: string): Attachment
			local at = Instance.new("Attachment")
			at.Name = "LucyAura_" .. name
			local parent: Instance
			if character then
				local found: Attachment? = nil
				for _, child in character:GetChildren() do
					if child:IsA("BasePart") then
						local candidate = child:FindFirstChild(name)
						if candidate and candidate:IsA("Attachment") then
							found = candidate
							break
						end
					end
				end
				if not found then
					local rootPart = character:FindFirstChild("HumanoidRootPart")
					local fallback = rootPart and rootPart:FindFirstChild("RootAttachment")
					found = if fallback and fallback:IsA("Attachment") then fallback else nil
				end
				assert(found, `[Lucy] aura "{props.type}": the character has no {name} or RootAttachment`)
				at.CFrame = found.CFrame
				parent = (found :: Attachment).Parent :: Instance
			else
				parent = holder :: BasePart
			end
			at.Parent = parent
			table.insert(self._attachments, { attachment = at, parent = parent })
			return at
		end,
		part = function(name: string): BasePart?
			local part = if character then character:FindFirstChild(name) else holder
			return if part and part:IsA("BasePart") then part else nil
		end,
		intro = function()
			return self._intro()
		end,
		elapsed = function()
			return self._elapsed()
		end,
		outro = function()
			return self._outro()
		end,
		strength = function()
			return self._strength()
		end,
		reducedMotion = function()
			return self._reduced()
		end,
		option = function(key: string): any
			local value = options[key]
			if value == nil then
				return defaults[key]
			end
			return value
		end,
		color = function(token: string): Color3
			local name = if string.sub(token, 1, 1) == "$" then string.sub(token, 2) else token
			local value = app and app.theme:resolve(name)
			return if typeof(value) == "Color3" then value else Color3.new(1, 1, 1)
		end,
		animate = function(rig: Instance, id: string): AnimationTrack?
			local controller: Instance? = rig:FindFirstChildWhichIsA("Humanoid")
				or rig:FindFirstChildWhichIsA("AnimationController")
			if not controller then
				local made = Instance.new("AnimationController")
				made.Parent = rig
				controller = made
			end
			local animator: Animator? = (controller :: Instance):FindFirstChildWhichIsA("Animator")
			if not animator then
				local made = Instance.new("Animator")
				made.Parent = controller
				animator = made
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if not ok then
				warn(`[Lucy] aura "{props.type}" could not load animation {id}: {track}`)
				return nil
			end
			track.Looped = true
			track:Play()
			if self._reduced() then
				track:AdjustSpeed(0)
			end
			table.insert(self._tracks, track)
			return track
		end,
		give = function(item: any): any
			return self._maid:give(item)
		end,
	}

	local scope = Reactive.effectScope(true)
	self._scope = scope
	scope:run(function()
		definition.build(ctx)
	end)

	root.Parent = character or workspace

	-- Reduced motion: the opening jumps to its end and loops hold still.
	local length = math.max(tonumber(definition.intro) or 0, 0)
	if self._reduced() then
		self._intro(length)
	end
	scope:run(function()
		Reactive.watch(Preferences.reducedMotion, function(reduced: boolean)
			self._reduced(reduced)
			for _, track in self._tracks do
				track:AdjustSpeed(if reduced then 0 else 1)
			end
			if reduced then
				self._intro(length)
			end
		end)
	end)

	if character then
		self._maid:give(character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self:destroy()
			end
		end))
	end
	if app and app.maid then
		app.maid:give(function()
			self:destroy()
		end)
	end

	if props.drive ~= false then
		self._stopDrive = Animate.drive(function(dt: number): boolean
			if self.destroyed then
				return true
			end
			self:step(dt)
			return self.destroyed
		end)
	end
	return self
end

-- Advances the aura one frame (a follower calls this; a lone aura drives itself).
function Handle.step(self: Handle, dt: number)
	if self.destroyed then
		return
	end
	local definition = self._definition
	if self.finishing then
		local length = math.max(tonumber(definition.outro) or 0, 0)
		local t = if self._reduced() then length else math.min(self._outro() + dt, length)
		self._outro(t)
		if t >= length then
			self:destroy()
		end
		return
	end
	if self.strength <= 0 or self._reduced() then
		return
	end
	local length = math.max(tonumber(definition.intro) or 0, 0)
	if self._intro() < length then
		self._intro(math.min(self._intro() + dt, length))
	end
	if definition.loop then
		self._elapsed(self._elapsed() + dt)
	end
end

-- 0 to 1. At 0 the aura is off: its attachments leave the character and it does not run.
function Handle.setStrength(self: Handle, strength: number)
	strength = math.clamp(strength, 0, 1)
	if self.destroyed or strength == self.strength then
		return
	end
	local wasOff = self.strength <= 0
	self.strength = strength
	self._strength(strength)
	local off = strength <= 0
	if off ~= wasOff then
		for _, entry in self._attachments do
			if entry.parent.Parent ~= nil or not off then
				entry.attachment.Parent = if off then nil else entry.parent
			end
		end
		self.root.Parent = if off then nil else (self.character or workspace)
	end
end

-- Plays the closing, then goes.
function Handle.finish(self: Handle)
	if self.destroyed or self.finishing then
		return
	end
	self.finishing = true
	if (tonumber(self._definition.outro) or 0) <= 0 then
		self:destroy()
	end
end

function Handle.destroy(self: Handle)
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self._stopDrive then
		self._stopDrive()
		self._stopDrive = nil
	end
	for _, track in self._tracks do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(self._tracks)
	self._scope:stop()
	self._maid:clean()
	for _, entry in self._attachments do
		entry.attachment:Destroy()
	end
	table.clear(self._attachments)
	self.root:Destroy()
	self.done:Fire()
	self.done:DisconnectAll()
end

local Follower = {}
Follower.__index = Follower

export type Follower = typeof(setmetatable(
	{} :: {
		app: any,
		auras: { [string]: Handle },
		destroyed: boolean,
		_options: { [string]: any },
		_warned: { [string]: boolean },
		_since: number,
		_stopDrive: (() -> ())?,
		_stopSubscribe: (() -> ())?,
	},
	Follower
))

local function defaultResolve(id: string): Model?
	local userId = tonumber(id)
	local player = userId and Players:GetPlayerByUserId(userId)
	return player and player.Character or nil
end

local function defaultFocus(): Vector3?
	local camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

--[[
	Aura.follow(app, options): wears every aura in the store on whoever it names. options:
		path      where the store keeps them ("server.auras")
		resolve   (id) -> Model?: the character for an id (default: the player with that UserId)
		hidden    a ref, getter or boolean: hides every aura while true
		max       how many run at once, nearest first (12)
		near      studs from the camera within which an aura is at full strength (40)
		far       studs beyond which it is off (90)
		focus     () -> Vector3: where distance is measured from (the camera)
		now       () -> number: the clock untilTime is read against (the server's)
	Goes with the App.
]]
function Aura.follow(app: any, options: { [string]: any }?): Follower
	local opts: { [string]: any } = options or {}
	local self = setmetatable({
		app = app,
		auras = {},
		destroyed = false,
		_options = opts,
		_warned = {},
		_since = math.huge,
	}, Follower) :: any

	self._stopSubscribe = app.state:subscribe(opts.path or "server.auras", function()
		self._since = math.huge -- look again on the next frame
	end)
	self._stopDrive = Animate.drive(function(dt: number): boolean
		if self.destroyed then
			return true
		end
		self:step(dt)
		return false
	end)
	app.maid:give(function()
		self:destroy()
	end)
	return self
end

-- Matches the auras to the store: puts on what is new, closes what went or ran out,
-- and remounts any whose character changed (a respawn).
function Follower.reconcile(self: Follower)
	local opts = self._options
	local resolve = opts.resolve or defaultResolve
	local now = (opts.now or serverNow)()
	local wanted: { [string]: boolean } = {}
	local entries = self.app.state:get(opts.path or "server.auras")
	if type(entries) == "table" then
		for id, kinds in entries do
			if type(kinds) ~= "table" then
				continue
			end
			local character = resolve(tostring(id))
			for kind, entry in kinds do
				local key = `{id}/{kind}`
				if type(entry) ~= "table" then
					continue
				end
				if not Aura.types[kind] then
					if not self._warned[kind] then
						self._warned[kind] = true
						warn(`[Lucy] no aura type "{kind}" registered; skipped`)
					end
					continue
				end
				local expired = type(entry.untilTime) == "number" and now >= entry.untilTime
				local current: Handle? = self.auras[key]
				if current and (current.character ~= character or (current.finishing and not expired)) then
					current:destroy() -- the character changed (no closing on one that went), or worn again
					current = nil
				end
				if not expired and character then
					wanted[key] = true
					if not current or current.destroyed then
						local props = table.clone(entry.options or {})
						props.type = kind
						props.character = character
						props.app = self.app
						props.drive = false
						local ok, made = pcall(Aura.new, props)
						if ok then
							self.auras[key] = made
							made.done:Connect(function()
								if self.auras[key] == made then
									self.auras[key] = nil
								end
							end)
						else
							warn(`[Lucy] aura "{kind}" on {id} failed to build: {made}`)
						end
					end
				end
			end
		end
	end
	for key, aura in self.auras do
		if not wanted[key] then
			aura:finish()
		end
	end
	self._since = 0
end

local RECHECK = 0.5 -- seconds between looks for respawns and ran out clocks

function Follower.step(self: Follower, dt: number)
	if self.destroyed then
		return
	end
	self._since += dt
	if self._since >= RECHECK then
		self:reconcile()
	end
	local opts = self._options
	local hidden = Reactive.toValue(opts.hidden)
	if type(hidden) == "function" then
		hidden = hidden()
	end
	local focus = (opts.focus or defaultFocus)()
	local max = opts.max or 12
	local near, far = opts.near or 40, opts.far or 90

	-- Nearest first, within the budget; distance fades between near and far.
	local order = {}
	for _, aura in self.auras do
		local at = anchorOf(aura.character, aura.point)
		local distance = if at and focus then (at - focus).Magnitude else math.huge
		table.insert(order, { aura = aura, distance = distance })
	end
	table.sort(order, function(a, b)
		return a.distance < b.distance
	end)
	for rank, item in order do
		local strength = 0
		if not hidden and rank <= max then
			strength = math.clamp((far - item.distance) / math.max(far - near, 1e-3), 0, 1)
		end
		item.aura:setStrength(strength)
		item.aura:step(dt)
	end
end

function Follower.destroy(self: Follower)
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self._stopDrive then
		self._stopDrive()
	end
	if self._stopSubscribe then
		self._stopSubscribe()
	end
	for _, aura in self.auras do
		aura:destroy()
	end
	table.clear(self.auras)
end

--[[
	Server side: who wears what. id is a UserId or a bot's id (no dots); type a registered aura.
	options:
		options   the type's options for this wearer
		seconds   a timed aura: it closes by itself this long from now
		now       the clock (workspace:GetServerTimeNow())
	Wearing a type again replaces it (a new clock, new options).
]]
function Aura.wear(server: any, id: any, kind: string, options: { [string]: any }?)
	local opts: { [string]: any } = options or {}
	local entry: { [string]: any } = { options = opts.options }
	if type(opts.seconds) == "number" then
		entry.untilTime = (opts.now or serverNow()) + opts.seconds
	end
	server.state:set(`shared.auras.{tostring(id)}.{kind}`, entry)
end

-- Takes one aura off, or every aura the id wears when kind is nil.
function Aura.take(server: any, id: any, kind: string?)
	local path = `shared.auras.{tostring(id)}`
	if kind then
		server.state:remove(`{path}.{kind}`)
		local left = server.state:get(path)
		if type(left) == "table" and next(left) == nil then
			server.state:remove(path)
		end
	else
		server.state:remove(path)
	end
end

-- Built-in types
Aura.register("glow", require(script.Parent.Auras.Glow))

return Aura
