--!strict
--[[
	Preview: render stories in Studio, in edit mode or in Play (ADR 0016).

	A story is a ModuleScript named "<Name>.story" that returns:

		return {
			title = "Button",              -- defaults to the module name
			group = "Components",          -- sidebar group ("Stories")
			description = "Variants and sizes",
			layout = "centered",           -- "centered" | "padded" | "fullscreen"
			width = 360,                   -- centred column width in pixels
			controls = {
				text = "Button",                         -- string
				disabled = false,                        -- boolean
				variant = { "default", "outline" },      -- choice, first is the default
				size = { options = { "sm", "md" }, default = "md" },
				value = { min = 0, max = 100, step = 1, default = 40 },  -- number
			},
			render = function(ctx)
				-- ctx.Lucy (this package), ctx.app, ctx.target, ctx.controls.<name> (a writable ref)
				local Lucy = ctx.Lucy
				return Lucy.Button.new({ text = ctx.controls.text, variant = ctx.controls.variant })
			end,
		}

	render runs with the story's own App as the current one, inside an effect
	scope: components and Lucy.new elements it creates go away with the mount.
	Return what to show (an Instance, a handle or a list); anything returned
	without a parent goes into ctx.target.

		local m = Lucy.Preview.mount(story, { theme = "light", device = "mobile" })
		m:set("variant", "outline") ; m:values() ; m:destroy()

		Lucy.Preview.show("Button")     -- command bar or Studio MCP, edit mode
		Lucy.Preview.clear()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local App = require(script.Parent.App)
local Component = require(script.Parent.Component)
local Context = require(script.Parent.Context)
local Reactive = require(script.Parent.Reactive)

export type Control = {
	name: string,
	kind: string, -- "boolean" | "string" | "number" | "choice"
	default: any,
	options: { any }?,
	min: number?,
	max: number?,
	step: number?,
}

export type Story = {
	id: string?,
	title: string?,
	group: string?,
	description: string?,
	layout: string?,
	width: number?,
	controls: { [string]: any }?,
	render: ((ctx: Context) -> any)?,
	module: ModuleScript?,
	loadError: string?,
	[string]: any,
}

export type Context = {
	Lucy: any,
	app: App.App,
	target: Frame,
	controls: { [string]: Reactive.Ref<any> },
	story: Story,
}

local Preview = {}

-- Input capabilities per device, as InputManager expects them.
Preview.devices = {
	desktop = { keyboard = true, mouse = true, viewport = Vector2.new(1280, 720) },
	mobile = { touch = true, viewport = Vector2.new(844, 390) },
	tablet = { touch = true, viewport = Vector2.new(1180, 820) },
	console = { tenFoot = true, gamepad = true, viewport = Vector2.new(1920, 1080) },
}

local rules: { Component.Rule } = {
	{
		selector = ".ui-preview-canvas",
		priority = 0,
		properties = { BackgroundColor3 = "$Background", BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-preview-error",
		priority = 0,
		properties = {
			TextColor3 = "$Destructive",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
			BackgroundTransparency = 1,
		},
	},
}
Preview.rules = rules

-- Controls -----------------------------------------------------------------------------

local function normalize(name: string, spec: any): Control
	local kind = typeof(spec)
	if kind == "boolean" then
		return { name = name, kind = "boolean", default = spec }
	elseif kind == "string" then
		return { name = name, kind = "string", default = spec }
	elseif kind == "number" then
		return { name = name, kind = "number", default = spec, step = 1 }
	elseif kind == "table" then
		local options = spec.options or (if spec[1] ~= nil then spec else nil)
		if options then
			local default = if spec.default ~= nil then spec.default else options[1]
			if table.find(options, default) == nil then
				error(
					`[Lucy] story control "{name}": default {tostring(default)} is not one of its options`,
					0
				)
			end
			return { name = name, kind = "choice", default = default, options = table.clone(options) }
		end
		if spec.min ~= nil or spec.max ~= nil or spec.default ~= nil then
			return {
				name = name,
				kind = "number",
				default = spec.default or spec.min or 0,
				min = spec.min,
				max = spec.max,
				step = spec.step or 1,
			}
		end
	end
	error(`[Lucy] story control "{name}": unsupported value {tostring(spec)}`, 0)
end

-- The story's controls, normalised and sorted by name.
function Preview.controlsOf(story: Story): { Control }
	local list: { Control } = {}
	local controls: { [string]: any } = story.controls or {}
	for name, spec in controls do
		table.insert(list, normalize(name, spec))
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

-- Finding stories ------------------------------------------------------------------------

local SUFFIX = ".story"

-- Every "<Name>.story" ModuleScript under root, sorted by group then title. A module
-- that fails to load is still listed, with `loadError` set, so the browser can show it.
function Preview.find(root: Instance?): { Story }
	local stories: { Story } = {}
	for _, module in (root or ReplicatedStorage):GetDescendants() do
		if module:IsA("ModuleScript") and string.sub(module.Name, -#SUFFIX) == SUFFIX then
			local id = string.sub(module.Name, 1, -#SUFFIX - 1)
			local ok, result = pcall(require, module)
			local story: Story
			if ok and type(result) == "table" then
				story = table.clone(result)
			else
				story = { loadError = if ok then "a story must return a table" else tostring(result) }
			end
			story.id = id
			story.module = module
			story.title = story.title or id
			story.group = story.group or "Stories"
			table.insert(stories, story)
		end
	end
	table.sort(stories, function(a, b)
		if a.group ~= b.group then
			return (a.group :: string) < (b.group :: string)
		end
		return (a.title :: string) < (b.title :: string)
	end)
	return stories
end

-- Mounting ---------------------------------------------------------------------------------

local Mounted = {}
Mounted.__index = Mounted

export type Mounted = typeof(setmetatable(
	{} :: {
		story: Story,
		app: App.App,
		gui: ScreenGui,
		canvas: Frame,
		target: Frame,
		controls: { [string]: Reactive.Ref<any> },
		error: string?,
		destroyed: boolean,
		_scope: Reactive.Scope,
		_previous: any,
	},
	Mounted
))

local function instanceOf(item: any): Instance?
	if typeof(item) == "Instance" then
		return item
	end
	if type(item) == "table" and typeof(item.Instance) == "Instance" then
		return item.Instance
	end
	return nil
end

-- Parents what render returned into the target, leaving anything already parented.
local function place(target: Instance, result: any)
	if result == nil then
		return
	end
	local single = instanceOf(result)
	local items = if single or type(result) ~= "table" then { result } else result
	local order = 0
	for _, item in items do
		local instance = instanceOf(item)
		if instance and instance.Parent == nil then
			order = Component.adopt(target, instance, order)
		end
	end
end

local function buildTarget(story: Story, canvas: Frame): Frame
	local layout = story.layout or "centered"
	if layout == "fullscreen" then
		return Component.box({ Name = "Target", Size = UDim2.fromScale(1, 1), Parent = canvas })
	end
	local target: Frame
	if layout == "padded" then
		target = Component.box({ Name = "Target", Size = UDim2.fromScale(1, 1), Parent = canvas })
		Component.create("UIPadding", {
			PaddingTop = UDim.new(0, 24),
			PaddingBottom = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 24),
			PaddingRight = UDim.new(0, 24),
			Parent = target,
		})
	elseif layout == "centered" then
		target = Component.box({
			Name = "Target",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(story.width or 360, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = canvas,
		})
	else
		error(`[Lucy] story layout "{layout}" must be "centered", "padded" or "fullscreen"`, 0)
	end
	Component.list({
		Padding = UDim.new(0, 12),
		HorizontalAlignment = if layout == "centered"
			then Enum.HorizontalAlignment.Center
			else Enum.HorizontalAlignment.Left,
		Parent = target,
	})
	return target
end

local function inputFor(device: string?): { [string]: any }?
	if device then
		local caps = Preview.devices[device]
		if not caps then
			error(`[Lucy] unknown preview device "{device}"`, 0)
		end
		return { watch = false, caps = caps }
	end
	if Players.LocalPlayer then
		return nil -- a running client follows real input
	end
	return { watch = false, caps = Preview.devices.desktop }
end

--[[
	options:
		parent       where the guis go (StarterGui in edit mode, PlayerGui on a client)
		theme        "light" | "dark" ...
		density      pin a density; otherwise it follows the device
		device       "desktop" | "mobile" | "tablet" | "console" (real input on a client if nil)
		baseColor, primary   as App.new
		controls     initial control values, overriding the story's defaults
		inset        { left, top, right, bottom } pixels to keep clear (a browser's sidebar)
		background   false to leave the canvas transparent
		displayOrder of the preview gui (5, below scenes)
]]
local function mountNow(story: Story, options: { [string]: any }?): Mounted
	local opts: { [string]: any } = options or {}
	local previous = Context.getCurrent()

	local app = App.new({
		theme = opts.theme,
		density = opts.density,
		baseColor = opts.baseColor,
		primary = opts.primary,
		parent = opts.parent,
		namePrefix = opts.namePrefix or "LucyPreview_",
		input = inputFor(opts.device),
	})
	app.theme:addRules("preview", Preview.rules)

	local gui = app:portal("preview", { displayOrder = opts.displayOrder or 5 })
	local inset = opts.inset or {}
	local left, top = inset.left or inset[1] or 0, inset.top or inset[2] or 0
	local right, bottom = inset.right or inset[3] or 0, inset.bottom or inset[4] or 0
	-- The canvas colour comes from a rule; an instance property would override it.
	local canvas = Component.create("Frame", {
		Name = "Canvas",
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(left, top),
		Size = UDim2.new(1, -(left + right), 1, -(top + bottom)),
		Tags = { "ui-preview-canvas" },
	})
	if opts.background == false then
		canvas.BackgroundTransparency = 1
	end
	canvas.Parent = gui

	local controls: { [string]: Reactive.Ref<any> } = {}
	local self: Mounted = setmetatable({
		story = story,
		app = app,
		gui = gui,
		canvas = canvas,
		target = canvas,
		controls = controls,
		error = nil,
		destroyed = false,
		_scope = Reactive.effectScope(true),
		_previous = previous,
	}, Mounted)

	local function fail(message: string)
		self.error = message
		self._scope:stop()
		for _, child in canvas:GetChildren() do
			child:Destroy()
		end
		self.target = canvas
		Component.create("TextLabel", {
			Name = "PreviewError",
			Text = `{story.title or story.id or "Story"} failed:\n{message}`,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(24, 24),
			Size = UDim2.new(1, -48, 1, -48),
			Tags = { "ui-preview-error" },
			Parent = canvas,
		})
		warn(`[Lucy] story {story.title or story.id or "?"}: {message}`)
	end

	local ok, err = pcall(function()
		if story.loadError then
			error(story.loadError, 0)
		end
		if type(story.render) ~= "function" then
			error("a story needs a render function", 0)
		end
		for _, control in Preview.controlsOf(story) do
			local initial = control.default
			if opts.controls and opts.controls[control.name] ~= nil then
				initial = opts.controls[control.name]
			end
			controls[control.name] = Reactive.ref(initial)
		end
		self.target = buildTarget(story, canvas)
		local render = story.render :: (Context) -> any
		-- The package this Preview belongs to, so stories never hard-code a require path.
		local Lucy = (require :: any)(script.Parent.Parent)
		local ctx: Context =
			{ Lucy = Lucy, app = app, target = self.target, controls = controls, story = story }
		-- App.new made the story app current; render and its components rely on that.
		Context.setCurrent(app)
		local result = self._scope:run(render, ctx)
		place(self.target, result)
	end)
	if not ok then
		fail(tostring(err))
	end
	return self
end

-- Untracked, so mounting inside an effect (a browser's) never subscribes it to the
-- story's own reads; only the mount's scope owns what render creates.
function Preview.mount(story: Story, options: { [string]: any }?): Mounted
	return Reactive.untrack(mountNow, story, options)
end

-- Writes a control (the same as calling its ref).
function Mounted.set(self: Mounted, name: string, value: any)
	local control = self.controls[name]
	if not control then
		error(`[Lucy] story has no control "{name}"`, 2)
	end
	control(value)
end

-- Current control values by name.
function Mounted.values(self: Mounted): { [string]: any }
	local out = {}
	for name, control in self.controls do
		out[name] = Reactive.peek(control)
	end
	return out
end

function Mounted.destroy(self: Mounted)
	if self.destroyed then
		return
	end
	self.destroyed = true
	self._scope:stop()
	self.app:destroy()
	local previous = self._previous
	if Context.getCurrent() == nil and previous and not previous.destroyed then
		Context.setCurrent(previous)
	end
end
Mounted.Destroy = Mounted.destroy

-- Edit-mode shortcuts ---------------------------------------------------------------------

local shown: Mounted? = nil

-- Mounts a story (a table, or a story id found under options.root or ReplicatedStorage),
-- replacing whatever show() mounted before.
function Preview.show(story: Story | string, options: { [string]: any }?): Mounted
	local resolved: Story
	if type(story) == "string" then
		local found: Story? = nil
		for _, candidate in Preview.find(options and options.root) do
			if candidate.id == story or candidate.title == story then
				found = candidate
				break
			end
		end
		if not found then
			error(`[Lucy] no story named "{story}"`, 2)
		end
		resolved = found :: Story
	else
		resolved = story
	end
	Preview.clear()
	local mounted = Preview.mount(resolved, options)
	shown = mounted
	return mounted
end

function Preview.current(): Mounted?
	return shown
end

function Preview.clear()
	if shown then
		shown:destroy()
		shown = nil
	end
end

return Preview
