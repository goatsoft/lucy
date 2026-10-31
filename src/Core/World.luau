--!strict
--[[
	World UI: SurfaceGuis and BillboardGuis made by the App on the client.

		local board = app:createSurface("Scoreboard", { adornee = workspace.Stage.Screen, pixelsPerStud = 50 })
		Lucy.Text.new({ text = function() return `Round {round()}` end, Parent = board })

		local tag = app:createBillboard("NameTag", { adornee = head, size = UDim2.fromOffset(200, 50) })

	Each gui goes in the App's parent (PlayerGui) with an Adornee, so mouse and touch
	clicks reach it, and is linked to the theme, so components and $Token rules work in
	it. It is never scaled for the screen: its size comes from the part (pixels per stud
	or a fixed canvas) or the billboard size. It goes when its part goes and with the App.
	World guis are not keyboard or gamepad navigation targets (App.activeGuis).

	surface options:
		adornee         the BasePart to draw on (required)
		face            Enum.NormalId (Front)
		pixelsPerStud   layout pixels per stud (50); ignored with canvasSize
		canvasSize      Vector2: a fixed canvas instead of pixels per stud
		lightInfluence  0 to 1 (0: not lit by the world)
		brightness      (1)
		alwaysOnTop     draw over the world (false)
		maxDistance     studs beyond which it hides (Roblox default: any distance)
		zOffset         (0)
		enabled         (true)

	billboard options:
		adornee         the BasePart or Attachment to hang it from (required)
		size            UDim2 (200 x 50 pixels)
		studsOffset     Vector3 (0, 0, 0)
		alwaysOnTop, maxDistance, lightInfluence, brightness, enabled as above
]]

local RunService = game:GetService("RunService")

local World = {}

local function editMode(): boolean
	return RunService:IsStudio() and not RunService:IsRunning()
end

local function option(value: any, default: any): any
	if value == nil then
		return default
	end
	return value
end

-- Shared by both kinds: name, parent, theme, lifetime.
local function finish(
	app: any,
	gui: LayerCollector,
	adornee: Instance,
	opts: { [string]: any }
): LayerCollector
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if editMode() then
		gui.Archivable = false
	end
	app.theme:link(gui)

	local connections: { RBXScriptConnection } = {}
	local function gone()
		if gui.Parent ~= nil then
			gui:Destroy()
		end
	end
	table.insert(connections, adornee.Destroying:Connect(gone))
	table.insert(
		connections,
		adornee.AncestryChanged:Connect(function()
			if not adornee:IsDescendantOf(game) then
				gone()
			end
		end)
	)
	gui.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end)
	app.maid:give(gui)

	gui.Parent = opts.parent or app.parent
	return gui
end

function World.surface(app: any, name: string, options: { [string]: any }?): SurfaceGui
	local opts: { [string]: any } = options or {}
	local adornee = opts.adornee
	if typeof(adornee) ~= "Instance" or not (adornee :: Instance):IsA("BasePart") then
		error(`[Lucy] createSurface("{name}") needs an adornee: the BasePart to draw on`, 2)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = app.namePrefix .. name
	gui.Adornee = adornee
	gui.Face = option(opts.face, Enum.NormalId.Front)
	if opts.canvasSize then
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = opts.canvasSize
	else
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = option(opts.pixelsPerStud, 50)
	end
	gui.LightInfluence = option(opts.lightInfluence, 0)
	gui.Brightness = option(opts.brightness, 1)
	gui.AlwaysOnTop = option(opts.alwaysOnTop, false)
	if opts.maxDistance ~= nil then
		gui.MaxDistance = opts.maxDistance
	end
	gui.ZOffset = option(opts.zOffset, 0)
	gui.Enabled = option(opts.enabled, true)
	gui.Active = true
	return finish(app, gui, adornee, opts) :: SurfaceGui
end

function World.billboard(app: any, name: string, options: { [string]: any }?): BillboardGui
	local opts: { [string]: any } = options or {}
	local adornee = opts.adornee
	if
		typeof(adornee) ~= "Instance"
		or not ((adornee :: Instance):IsA("BasePart") or (adornee :: Instance):IsA("Attachment"))
	then
		error(`[Lucy] createBillboard("{name}") needs an adornee: a BasePart or Attachment`, 2)
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = app.namePrefix .. name
	gui.Adornee = adornee
	gui.Size = option(opts.size, UDim2.fromOffset(200, 50))
	gui.StudsOffset = option(opts.studsOffset, Vector3.zero)
	gui.LightInfluence = option(opts.lightInfluence, 0)
	gui.Brightness = option(opts.brightness, 1)
	gui.AlwaysOnTop = option(opts.alwaysOnTop, false)
	if opts.maxDistance ~= nil then
		gui.MaxDistance = opts.maxDistance
	end
	gui.Enabled = option(opts.enabled, true)
	gui.Active = true
	return finish(app, gui, adornee, opts) :: BillboardGui
end

return World
