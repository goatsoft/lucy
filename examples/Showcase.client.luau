--[[
	Showcase: a story browser built with Lucy itself (ADR 0016).

	Lists every *.story module under LucyExamples, renders the selected one between
	the sidebars and generates controls bound to the story's refs, so a switch in
	the panel and the component on the canvas stay in step both ways. Theme and
	device switch live.

	In the dev place this runs on Play (test.project.json maps it into
	StarterPlayerScripts). In a game, copy it into StarterPlayerScripts and point
	`root` at the folder holding your own stories.

	Edit mode has no gui input; render a single story there instead:
		require(game.ReplicatedStorage.Lucy).Preview.show("Button", { root = game.ReplicatedStorage.LucyExamples })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lucy = require(ReplicatedStorage:WaitForChild("Lucy"))
local root = ReplicatedStorage:WaitForChild("LucyExamples")

local SIDEBAR, PANEL = 240, 300
local DEVICES = { "auto", "desktop", "mobile", "tablet", "console" }

local stories = Lucy.Preview.find(root)
local byId = {}
for _, story in stories do
	byId[story.id] = story
end

-- The browser has its own App, so a story's theme or density never moves the chrome.
local ui = Lucy.App.new({
	theme = "dark",
	baseColor = "zinc",
	primary = "violet",
	namePrefix = "Stories_",
	setCurrent = false,
})
ui.theme:addRules("browser", {
	{
		selector = ".browser-pane",
		priority = 0,
		properties = { BackgroundColor3 = "$Card", BackgroundTransparency = 0 },
	},
	{ selector = ".browser-pane::UIStroke", priority = 0, properties = { Color = "$Border", Thickness = 1 } },
	{
		selector = ".browser-heading",
		priority = 0,
		properties = {
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSansSemibold",
			TextSize = "$TextXs",
			BackgroundTransparency = 1,
		},
	},
})

local selected = Lucy.ref(if stories[1] then stories[1].id else nil)
local device = Lucy.ref("auto")
local theme = ui.state:ref("theme")
local current = Lucy.ref(nil) -- the mounted story
local saved = {} -- control values per story, kept across switches

-- Mount the selected story; switching story or device remounts, keeping its values.
Lucy.watchEffect(function()
	local id, dev = selected(), device()
	local story = id and byId[id]
	if not story then
		return
	end
	local mounted = Lucy.Preview.mount(story, {
		parent = ui.parent,
		theme = Lucy.peek(theme),
		device = if dev == "auto" then nil else dev,
		baseColor = "zinc",
		primary = "violet",
		inset = { left = SIDEBAR, right = PANEL },
		controls = saved[id],
	})
	current(mounted)
	Lucy.onCleanup(function()
		saved[id] = mounted:values()
		mounted:destroy()
	end)
end)

-- The theme switches in place, no remount.
Lucy.watch(theme, function(name)
	local mounted = Lucy.peek(current)
	if mounted and not mounted.destroyed then
		mounted.app:setTheme(name)
	end
end)

-- Widgets ---------------------------------------------------------------------------

local function heading(text)
	return Lucy.new("TextLabel")({
		Text = string.upper(text),
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		Tags = { "browser-heading" },
	})
end

local function row(children)
	return Lucy.Stack.new({
		app = ui,
		direction = "horizontal",
		gap = "Space1",
		wrap = true,
		size = UDim2.fromScale(1, 0),
		automaticSize = Enum.AutomaticSize.Y,
		children = children,
	})
end

local function choice(options, ref)
	local buttons = {}
	for _, option in options do
		table.insert(
			buttons,
			Lucy.Button.new({
				app = ui,
				text = tostring(option),
				size = "sm",
				variant = function()
					return if ref() == option then "default" else "outline"
				end,
				onClick = function()
					ref(option)
				end,
			})
		)
	end
	return row(buttons)
end

local function field(name, child)
	return Lucy.Stack.new({
		app = ui,
		gap = "Space1",
		children = { Lucy.Text.new({ app = ui, text = name, variant = "label" }), child },
	})
end

-- One widget per control kind, bound two-way to the story's ref.
local function controlWidget(control, ref)
	if control.kind == "boolean" then
		return Lucy.Switch.new({ app = ui, label = control.name, checked = ref })
	elseif control.kind == "string" then
		return field(control.name, Lucy.Input.new({ app = ui, value = ref, placeholder = control.name }))
	elseif control.kind == "choice" then
		return field(control.name, choice(control.options, ref))
	end
	local function step(direction)
		return function()
			local value = ref() + direction * (control.step or 1)
			if control.min then
				value = math.max(control.min, value)
			end
			if control.max then
				value = math.min(control.max, value)
			end
			ref(value)
		end
	end
	return field(
		control.name,
		row({
			Lucy.Button.new({ app = ui, text = "-", size = "sm", variant = "outline", onClick = step(-1) }),
			Lucy.Text.new({
				app = ui,
				autoWidth = true,
				text = function()
					return tostring(ref())
				end,
			}),
			Lucy.Button.new({ app = ui, text = "+", size = "sm", variant = "outline", onClick = step(1) }),
		})
	)
end

local function pane(props)
	local frame = Lucy.new("ScrollingFrame")({
		Name = props.name,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.new(0, props.width, 1, 0),
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Tags = { "browser-pane" },
		-- Padding lives on an inner frame: in a ScrollingFrame, scale widths ignore UIPadding.
		Lucy.new("Frame")({
			Name = "Inner",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Lucy.new("UIPadding")({
				PaddingTop = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),
			props.child,
		}),
	})
	return frame
end

-- Chrome ----------------------------------------------------------------------------

local gui = ui:createGui("Browser", { displayOrder = 850 })

-- Sidebar: stories grouped, the selected one highlighted.
local list = { Lucy.Text.new({ app = ui, text = "Lucy stories", variant = "h4" }) }
local group = nil
for _, story in stories do
	if story.group ~= group then
		group = story.group
		table.insert(list, heading(group))
	end
	table.insert(
		list,
		Lucy.Button.new({
			app = ui,
			text = story.title,
			size = "sm",
			variant = function()
				return if selected() == story.id then "secondary" else "ghost"
			end,
			onClick = function()
				selected(story.id)
			end,
		})
	)
end
pane({
	name = "Sidebar",
	width = SIDEBAR,
	position = UDim2.fromScale(0, 0),
	child = Lucy.Stack.new({ app = ui, gap = "Space1", children = list }),
}).Parent =
	gui

-- Panel: the story's description and controls, then theme and device.
pane({
	name = "Controls",
	width = PANEL,
	anchor = Vector2.new(1, 0),
	position = UDim2.fromScale(1, 0),
	child = Lucy.Stack.new({
		app = ui,
		gap = "Space4",
		children = {
			-- Rebuilt for each mount, so the widgets bind to that mount's refs.
			Lucy.new("Frame")({
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Lucy.new("UIListLayout")({
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				function()
					local mounted = current()
					if not mounted then
						return nil
					end
					local story = mounted.story
					local items = {
						Lucy.Text.new({ app = ui, text = story.title, variant = "h4" }),
						Lucy.Text.new({
							app = ui,
							text = story.description or story.group,
							variant = "muted",
						}),
					}
					if mounted.error then
						table.insert(
							items,
							Lucy.Badge.new({ app = ui, text = "Render failed", variant = "destructive" })
						)
					end
					for _, control in Lucy.Preview.controlsOf(story) do
						local ref = mounted.controls[control.name]
						if ref then
							table.insert(items, controlWidget(control, ref))
						end
					end
					if next(mounted.controls) == nil and not mounted.error then
						table.insert(
							items,
							Lucy.Text.new({ app = ui, text = "No controls.", variant = "muted" })
						)
					end
					return items
				end,
			}),
			Lucy.Separator.new({ app = ui }),
			Lucy.Switch.new({
				app = ui,
				label = "Dark theme",
				checked = Lucy.computed({
					get = function()
						return theme() == "dark"
					end,
					set = function(dark)
						theme(if dark then "dark" else "light")
					end,
				}),
			}),
			field("device", choice(DEVICES, device)),
		},
	}),
}).Parent =
	gui

if #stories == 0 then
	ui.toast.warning("No stories found", { description = `Nothing named *.story under {root:GetFullName()}` })
end
