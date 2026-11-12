--!strict
--[[
	Adaptive: proportional scaling and responsive helpers (ADR 0006).

	Components are authored in pixels at a base resolution (1280x720 by default),
	the way web UI is authored in CSS px. Each ScreenGui gets one UIScale that
	scales the whole tree to the device, so layouts keep their proportions from
	phone to TV without every component doing Scale-based maths.

		Adaptive.attach(gui, { base = Vector2.new(1280, 720), min = 0.6, max = 2 })
		Adaptive.aspect(frame, 16 / 9)          -- UIAspectRatioConstraint
		Adaptive.clamp(frame, minSize, maxSize) -- UISizeConstraint
		Adaptive.fit(panel, { room = fn })      -- shrink a panel (text and all) into its room
		Adaptive.breakpoints(gui)               -- StyleQuery "@Compact" / "@Regular" / "@Wide"
]]

local Workspace = game:GetService("Workspace")

local Adaptive = {}

Adaptive.defaults = {
	base = Vector2.new(1280, 720),
	min = 0.5,
	max = 2,
	mode = "fit", -- "fit" | "width" | "height"
}

--[[
	Per-device scaling. Layouts are authored once at 1280x720; each device class
	gets a base that keeps text readable and touch targets usable there:
	  mobile   phones: scale against a base a little smaller than 1280x720, so the UI shrinks to
	           fit a phone (735x413 shows at about 0.77) while text stays readable; touch
	           targets come from the touch density's taller controls
	  tablet   iPad-class screens
	  desktop  shrink a little on small windows, grow on big monitors
	  console  TVs: never shrink, grow for the 10-foot view
	App switches profile when InputManager reports a new device.
]]
Adaptive.profiles = {
	mobile = { base = Vector2.new(960, 540), min = 0.6, max = 1.25, mode = "fit" },
	tablet = { base = Vector2.new(1024, 640), min = 0.85, max = 1.5, mode = "fit" },
	desktop = { base = Vector2.new(1280, 720), min = 0.75, max = 2, mode = "fit" },
	console = { base = Vector2.new(1280, 720), min = 1, max = 2, mode = "fit" },
}

-- Width bands in pre-scale pixels. Upper bound is exclusive.
Adaptive.bands = {
	{ name = "Compact", min = 0, max = 720 },
	{ name = "Regular", min = 720, max = 1280 },
	{ name = "Wide", min = 1280, max = math.huge },
}

function Adaptive.computeScale(viewport: Vector2, options: { [string]: any }?): number
	local opts: { [string]: any } = options or {}
	local base: Vector2 = opts.base or Adaptive.defaults.base
	local min = opts.min or Adaptive.defaults.min
	local max = opts.max or Adaptive.defaults.max
	local mode = opts.mode or Adaptive.defaults.mode
	if viewport.X <= 0 or viewport.Y <= 0 then
		return 1
	end
	local sx, sy = viewport.X / base.X, viewport.Y / base.Y
	local scale
	if mode == "width" then
		scale = sx
	elseif mode == "height" then
		scale = sy
	else
		scale = math.min(sx, sy)
	end
	return math.clamp(scale, min, max)
end

-- Under this height (pre-scale pixels) a screen is short: a landscape phone, a short window.
-- Width bands miss it (a landscape phone is Regular wide).
Adaptive.shortHeight = 500

-- "short" or "tall" for a screen `height` pre-scale pixels high
function Adaptive.heightFor(height: number): string
	return if height > 0 and height < Adaptive.shortHeight then "short" else "tall"
end

function Adaptive.breakpointFor(width: number): string
	for _, band in Adaptive.bands do
		if width >= band.min and width < band.max then
			return band.name
		end
	end
	return Adaptive.bands[#Adaptive.bands].name
end

local function cameraViewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.zero
end

--[[
	Attaches a UIScale to `gui` and keeps it in sync with the viewport.
	options: base, min, max, mode, getViewport (for tests), watch (default true)
	Returns a handle with .scale, :refresh(), :destroy().
]]
function Adaptive.attach(gui: Instance, options: { [string]: any }?)
	local opts: { [string]: any } = options or {}
	-- A ScreenGui outside the game reports a made-up 800x600 (App attaches before parenting),
	-- so its own size counts only once it is in the game; until then, the camera's viewport
	local getViewport: () -> Vector2 = opts.getViewport
		or function()
			if gui:IsA("ScreenGui") and gui:IsDescendantOf(game) and gui.AbsoluteSize.X > 0 then
				return gui.AbsoluteSize
			end
			return cameraViewport()
		end

	local existing = gui:FindFirstChild("LucyScale")
	local scale: UIScale
	if existing and existing:IsA("UIScale") then
		scale = existing
	else
		scale = Instance.new("UIScale")
		scale.Name = "LucyScale"
		scale.Parent = gui
	end

	local handle: any = { scale = scale, connections = {} :: { RBXScriptConnection }, options = opts }

	function handle.refresh(_self)
		scale.Scale = Adaptive.computeScale(getViewport(), handle.options)
	end

	-- Swap scaling options (e.g. a new device profile) and rescale.
	function handle.configure(_self, newOptions: { [string]: any })
		handle.options = newOptions
		handle:refresh()
	end

	function handle.destroy(_self)
		for _, connection in handle.connections do
			connection:Disconnect()
		end
		handle.connections = {}
		scale:Destroy()
	end
	handle.Destroy = handle.destroy

	handle:refresh()

	if opts.watch ~= false then
		if gui:IsA("ScreenGui") then
			table.insert(
				handle.connections,
				gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					handle:refresh()
				end)
			)
		end
		local camera = Workspace.CurrentCamera
		if camera then
			table.insert(
				handle.connections,
				camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					handle:refresh()
				end)
			)
		end
	end

	return handle
end

-- Lock a frame to an aspect ratio (width / height).
function Adaptive.aspect(
	guiObject: Instance,
	ratio: number,
	options: { [string]: any }?
): UIAspectRatioConstraint
	local opts: { [string]: any } = options or {}
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ratio
	constraint.AspectType = opts.aspectType or Enum.AspectType.FitWithinMaxSize
	constraint.DominantAxis = opts.dominantAxis or Enum.DominantAxis.Width
	constraint.Parent = guiObject
	return constraint
end

-- The scale that fits something `natural` big (pixels at scale 1) into `room`: 1 when it fits,
-- less when it does not, never under `min`.
function Adaptive.fitScale(natural: Vector2, room: Vector2, min: number?): number
	if natural.X <= 0 or natural.Y <= 0 then
		return 1
	end
	return math.clamp(math.min(room.X / natural.X, room.Y / natural.Y), min or 0.5, 1)
end

--[[
	Shrinks a panel to fit the room it has, the way the app's scale fits the
	whole UI to the screen: one UIScale ("LucyFit") on the panel, so its text,
	icons and spacing shrink together. Never grows it past its own size.
	options:
	  room    () -> Vector2: the room in pixels (default: the parent's AbsoluteSize)
	  min     the smallest scale (default 0.5)
	  watch   more signals that change the room (the panel's own size and its
	          parent's are watched, whichever parent it has)
	Returns a handle with .scale, :refresh() and :destroy().
]]
function Adaptive.fit(guiObject: GuiObject, options: { [string]: any }?)
	local opts: { [string]: any } = options or {}
	local scale = Instance.new("UIScale")
	scale.Name = "LucyFit"
	scale.Parent = guiObject
	local function room(): Vector2
		if opts.room then
			return opts.room()
		end
		local parent = guiObject.Parent
		return if parent and parent:IsA("GuiBase2d")
			then parent.AbsoluteSize
			else Vector2.new(math.huge, math.huge)
	end

	local handle: any = { scale = scale, connections = {} :: { RBXScriptConnection } }
	-- Its parent's size, whichever parent it has now (it may be parented after fit is called)
	local parentSize: RBXScriptConnection? = nil
	function handle.refresh(_self)
		-- Its size at scale 1: what it shows now, before this scale
		local natural = guiObject.AbsoluteSize / math.max(scale.Scale, 0.01)
		local wanted = Adaptive.fitScale(natural, room(), opts.min)
		if math.abs(wanted - scale.Scale) > 0.005 then
			scale.Scale = wanted
		end
	end
	function handle.destroy(_self)
		for _, connection in handle.connections do
			connection:Disconnect()
		end
		handle.connections = {}
		if parentSize then
			parentSize:Disconnect()
			parentSize = nil
		end
		scale:Destroy()
	end
	handle.Destroy = handle.destroy

	local function watch(signal: RBXScriptSignal)
		table.insert(
			handle.connections,
			signal:Connect(function()
				handle:refresh()
			end)
		)
	end
	watch(guiObject:GetPropertyChangedSignal("AbsoluteSize"))
	local function followParent()
		if parentSize then
			parentSize:Disconnect()
			parentSize = nil
		end
		local parent = guiObject.Parent
		if parent and parent:IsA("GuiBase2d") then
			parentSize = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				handle:refresh()
			end)
		end
		handle:refresh()
	end
	table.insert(handle.connections, guiObject:GetPropertyChangedSignal("Parent"):Connect(followParent))
	followParent()
	for _, signal in opts.watch or {} do
		watch(signal)
	end
	handle:refresh()
	return handle
end

-- Keep a frame between min and max pixel sizes.
function Adaptive.clamp(guiObject: Instance, minSize: Vector2?, maxSize: Vector2?): UISizeConstraint
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = minSize or Vector2.zero
	constraint.MaxSize = maxSize or Vector2.new(math.huge, math.huge)
	constraint.Parent = guiObject
	return constraint
end

-- Creates StyleQuery instances so rules can use "@Compact", "@Regular" and "@Wide".
function Adaptive.breakpoints(gui: Instance): { [string]: StyleQuery }
	local queries: { [string]: StyleQuery } = {}
	for _, band in Adaptive.bands do
		local found = gui:FindFirstChild(band.name)
		local query: StyleQuery
		if found and found:IsA("StyleQuery") then
			query = found
		else
			query = Instance.new("StyleQuery")
			query.Name = band.name
			pcall(function()
				local conditions: { [string]: any } = { MinSize = Vector2.new(band.min, 0) }
				if band.max < math.huge then
					conditions.MaxSize = Vector2.new(band.max, 100000)
				end
				query:SetConditions(conditions)
			end)
			query.Parent = gui
		end
		queries[band.name] = query
	end
	return queries
end

function Adaptive.isTouch(): boolean
	local UserInputService = game:GetService("UserInputService")
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return Adaptive
