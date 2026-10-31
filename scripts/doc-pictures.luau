--[[
	Renders the docs examples in Studio, in edit mode, for their pictures
	(docs/development.md "Example pictures"). The LucyTests place syncs this as
	ReplicatedStorage.LucyDocPictures (test.project.json).

	1. `node scripts/doc-previews.ts serve` serves the marked examples and turns the
	   pixels sent back into WebP pictures.
	2. In Studio's edit data model:

		local R = require(game.ReplicatedStorage.LucyDocPictures)
		R.start()                         -- loads the examples, copies Lucy, registers the docs icons
		R.only({ "components-button" })   -- optional: just these
		R.run()                           -- every example, dark then light, captured and sent
		R.stop()                          -- takes away everything the renderer made

	run() is next("dark"), capture("dark", lines), again("light"), capture("light",
	lines) until next() returns "done"; the steps can be called one by one. Each box
	line reads `name x0,y0,x1,y1 vp=W,H`, in viewport pixels.

	Examples run with stand-ins for names they only borrow (tracks, a settings panel)
	and for a client (Players.LocalPlayer, remotes that answer nothing), so no real
	server script ever runs.
]]
--!nocheck
local AssetService = game:GetService("AssetService")
local CaptureService = game:GetService("CaptureService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local S = {}
S.SLOT = 560
S.GAP = 56
S.MARGIN = 28
S.URL = "http://127.0.0.1:38991/"
-- Around what an example drew, in capture pixels.
S.PAD = 40

local STATE = {
	player = { name = "DJ Lucy", coins = 1250, level = 12, hype = 72, combo = 8 },
	settings = { music = 80, sfx = 60, crowd = 40, lights = true, danceSpeed = 1 },
	booth = { bpm = 124, crossfade = 0, deck = "A" },
}

function S.load(file)
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, body = pcall(function()
		return HttpService:GetAsync(S.URL .. file .. "?t=" .. os.clock(), true)
	end)
	HttpService.HttpEnabled = was
	assert(ok, body)
	return HttpService:JSONDecode(body)
end

function S.clear()
	for _, undo in S.undo or {} do
		pcall(undo)
	end
	S.undo = {}
	if S.m then
		pcall(function()
			S.m:destroy()
		end)
		S.m = nil
	end
	for _, g in StarterGui:GetChildren() do
		if g.Name:sub(1, 12) == "LucyPreview_" then
			g:Destroy()
		end
	end
end

function S.mount(theme)
	S.clear()
	local m = S.Lucy.Preview.mount({ layout = "fullscreen", render = function() end }, {
		theme = theme,
		parent = StarterGui,
		device = "desktop",
	})
	for k, v in STATE do
		m.app.state:set(k, v)
	end
	S.m = m
	return m
end

-- Rect helpers: {x0, y0, x1, y1}
local function union(a, b)
	if not a then
		return b
	end
	if not b then
		return a
	end
	return { math.min(a[1], b[1]), math.min(a[2], b[2]), math.max(a[3], b[3]), math.max(a[4], b[4]) }
end
local function clip(a, b)
	local r = { math.max(a[1], b[1]), math.max(a[2], b[2]), math.min(a[3], b[3]), math.min(a[4], b[4]) }
	if r[3] <= r[1] or r[4] <= r[2] then
		return nil
	end
	return r
end
local function rectOf(g)
	local p, s = g.AbsolutePosition, g.AbsoluteSize
	return { p.X, p.Y, p.X + s.X, p.Y + s.Y }
end

-- Is g shown, and what is it clipped to, up to root?
local function shown(g, root)
	local area = { -1e6, -1e6, 1e6, 1e6 }
	local node = g
	while node and node ~= root.Parent do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return nil
			end
			if node ~= g and node.ClipsDescendants then
				area = clip(area, rectOf(node))
				if not area then
					return nil
				end
			end
		elseif node:IsA("LayerCollector") and not node.Enabled then
			return nil
		end
		node = node.Parent
	end
	return area
end

local TEXT = { TextLabel = true, TextButton = true, TextBox = true }
local IMAGE = { ImageLabel = true, ImageButton = true }

-- The part of root's descendants that draws something, as a rect.
function S.ink(root, screen)
	local acc
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			local area = shown(d, root)
			local r = area and rectOf(d)
			if r and r[3] > r[1] and r[4] > r[2] then
				local box
				if d.BackgroundTransparency < 1 then
					box = r
				end
				local stroke = d:FindFirstChildOfClass("UIStroke")
				if stroke and stroke.Enabled and stroke.Transparency < 1 then
					box = r
				end
				if not box and IMAGE[d.ClassName] and d.Image ~= "" and d.ImageTransparency < 1 then
					box = r
				end
				if
					not box
					and TEXT[d.ClassName]
					and d.TextTransparency < 1
					and (d.Text ~= "" or (d.ClassName == "TextBox" and d.PlaceholderText ~= ""))
				then
					local tb = d.TextBounds
					local w, h = math.min(tb.X, r[3] - r[1]), math.min(tb.Y, r[4] - r[2])
					local x = r[1]
					if d.TextXAlignment == Enum.TextXAlignment.Right then
						x = r[3] - w
					elseif d.TextXAlignment == Enum.TextXAlignment.Center then
						x = (r[1] + r[3] - w) / 2
					end
					local y = r[2]
					if d.TextYAlignment == Enum.TextYAlignment.Bottom then
						y = r[4] - h
					elseif d.TextYAlignment == Enum.TextYAlignment.Center then
						y = (r[2] + r[4] - h) / 2
					end
					if w > 0 and h > 0 then
						box = { x, y, x + w, y + h }
					end
				end
				-- A backdrop that covers the screen is not the example.
				if
					box
					and screen
					and (box[3] - box[1]) >= screen.X * 0.95
					and (box[4] - box[2]) >= screen.Y * 0.95
				then
					box = nil
				end
				if box then
					acc = union(acc, clip(box, area))
				end
			end
		end
	end
	return acc
end

-- The other guis the app made (overlays, toasts), apart from the preview canvas.
local function overlayGuis()
	local out = {}
	for _, g in StarterGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Name:sub(1, 12) == "LucyPreview_" and g ~= S.m.gui then
			table.insert(out, g)
		end
	end
	return out
end

-- Lucy as the example sees it: every component it makes is noted, so whatever is
-- left without a parent at the end (the example's roots) can be put on screen.
local function watchedLucy(made)
	local wrapped = {}
	-- A whole client script makes its own App; it gets the preview's, with its state.
	wrapped.App = setmetatable({
		new = function(options)
			local app = S.m.app
			if options and options.state then
				for k, v in options.state do
					if app.state:get(k) == nil then
						app.state:set(k, v)
					end
				end
			end
			return app -- the picture's theme wins over options.theme
		end,
		current = function()
			return S.m.app
		end,
	}, { __index = S.Lucy.App })
	return setmetatable({}, {
		__index = function(_, key)
			if wrapped[key] then
				return wrapped[key]
			end
			local value = S.Lucy[key]
			if type(value) == "table" and type(rawget(value, "new")) == "function" then
				if not wrapped[key] then
					local proxy = {
						new = function(...)
							local handle = value.new(...)
							table.insert(made, handle)
							return handle
						end,
					}
					if key == "Icon" then
						-- Icons an example registers are taken back after its picture.
						proxy.register = function(map)
							local undo = value.register(map)
							table.insert(S.undo, undo)
							return undo
						end
					end
					wrapped[key] = setmetatable(proxy, { __index = value })
				end
				return wrapped[key]
			end
			return value
		end,
	})
end

local function instanceOf(item)
	if typeof(item) == "Instance" then
		return item
	end
	if type(item) == "table" and typeof(rawget(item, "Instance")) == "Instance" then
		return item.Instance
	end
	if type(item) == "table" then
		local ok, inst = pcall(function()
			return item.Instance
		end)
		if ok and typeof(inst) == "Instance" then
			return inst
		end
	end
	return nil
end

-- Things an example may use without defining them, from the Club Lucy cast.
local function fixtures(lucy, slot)
	local function track(id, title, artist, bpm, length)
		return {
			id = id,
			title = title,
			name = title,
			artist = artist,
			bpm = bpm,
			length = length,
			coverId = "",
		}
	end
	local tracks = {
		track("neon-nights", "Neon Nights", "DJ Lucy", 124, 214),
		track("bassline-bounce", "Bassline Bounce", "Pixel Pulse", 128, 198),
		track("sunset-groove", "Sunset Groove", "The Glowsticks", 118, 241),
		track("midnight-drop", "Midnight Drop", "DJ Lucy", 140, 187),
	}
	local nova = { Name = "NovaDances", DisplayName = "Nova", UserId = 2 }
	local f = {
		tracks = tracks,
		song = tracks[1],
		track = tracks[1],
		player = { Name = "DJLucy", DisplayName = "DJ Lucy", UserId = 1 },
		friend = nova,
		emote = { id = "moonwalk", name = "Moonwalk", price = 300 },
		owned = function()
			return true
		end,
		streamerMode = lucy.ref(false),
		clubAssets = {},
		discoBall = {},
		remotes = setmetatable({}, {
			__index = function()
				return { FireServer = function() end, InvokeServer = function() end }
			end,
		}),
		cover = function()
			return lucy.Icon.new({ icon = "lucide-extended:disc-3-filled", size = "lg" })
		end,
	}
	local content = Instance.new("Frame")
	content.Name = "content"
	content.BackgroundTransparency = 1
	content.AutomaticSize = Enum.AutomaticSize.XY
	content.Parent = slot
	f.panel = slot
	-- A row lays its children out side by side, as the page means it to.
	local row = Instance.new("Frame")
	row.Name = "row"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	row.Parent = slot
	local dances = {
		{ "Moonwalk", "star" },
		{ "Robot", "zap" },
		{ "Shuffle", "footprints" },
		{ "Twirl", "sparkles" },
		{ "Wave", "heart" },
		{ "Groove", "music" },
	}
	local function list(make)
		local out = {}
		for i, d in dances do
			out[i] = make(d[1], "lucide-extended:" .. d[2] .. "-filled", i)
		end
		return out
	end
	f.emoteCards = list(function(n, icon)
		return S.Lucy.Button.new({ text = n, icon = icon, variant = "outline" })
	end)
	f.emoteButtons = list(function(n, icon)
		return S.Lucy.Button.new({ text = n, icon = icon, variant = "secondary" })
	end)
	f.trackCards = {}
	for i, t in tracks do
		f.trackCards[i] = S.Lucy.Item.new({
			title = t.title,
			description = `{t.artist}, {t.bpm} BPM`,
			variant = "muted",
			size = "sm",
		})
	end
	f.boothButtons = {
		S.Lucy.Button.new({ text = "Play", icon = "lucide-extended:play-filled" }),
		S.Lucy.Button.new({
			text = "Skip",
			icon = "lucide-extended:skip-forward-filled",
			variant = "secondary",
		}),
		S.Lucy.Button.new({ text = "Queue", icon = "lucide-extended:list-music-filled", variant = "outline" }),
	}
	f.crewRows = {}
	for i, n in { "Nova", "Beatrix", "Kai", "Juno", "Remy" } do
		f.crewRows[i] = S.Lucy.Item.new({
			title = n,
			description = "On the Dance Floor",
			media = S.Lucy.Avatar.new({ name = n }),
			size = "sm",
		})
	end
	f.dancers = lucy.ref({
		{ id = "nova", name = "Nova", level = 18, hype = 9840 },
		{ id = "lucy", name = "DJ Lucy", level = 12, hype = 9125 },
		{ id = "kai", name = "Kai", level = 15, hype = 8410 },
		{ id = "juno", name = "Juno", level = 9, hype = 7360 },
		{ id = "remy", name = "Remy", level = 7, hype = 6120 },
	})
	f.columns = {
		{ key = "name", header = "Dancer", width = { fill = 2 } },
		{ key = "level", header = "Level", width = 88, align = "right" },
		{ key = "hype", header = "Hype", width = 96, align = "right" },
	}
	f.clubRules =
		"1. Be kind on the Dance Floor. Everyone is here to have fun.\n\n2. No spamming emotes in someone's face. Give the crew room to move.\n\n3. Requests go in the queue. DJ Lucy plays them in order, so be patient.\n\n4. The Booth is for the DJ on the decks. Ask before you step up.\n\n5. Coins you earn are yours. Trading them for real money is not allowed.\n\n6. Report bad behaviour with the menu, not in chat."
	f.reloadSortedBy = function() end
	f.loadNextPage = function() end
	f.icon = S.Lucy.Icon.new({ icon = "lucide-extended:sparkles-filled", size = "lg" })
	f.name = S.Lucy.Text.new({ text = "Moonwalk", variant = "large" })
	-- Containers an example parents to without making them: the picture's slot.
	for _, name in
		{
			"settings",
			"crewList",
			"podium",
			"list",
			"emoteShop",
			"loadingScreen",
			"hud",
			"menu",
			"shop",
			"screen",
			"container",
			"sidebar",
			"card",
			"column",
			"queueList",
			"queue",
			"leaderboard",
			"booth",
			"lobby",
			"wardrobe",
			"body",
			"header",
			"footer",
			"content",
		}
	do
		f[name] = slot
	end
	f.row, f.toolbar = row, row
	return f
end

local function run(code, slot, after)
	if after and after ~= "" then
		code = code .. "\n" .. after
	end
	local fn, err = loadstring(code)
	if not fn then
		return "compile: " .. tostring(err)
	end
	local made = {}
	local lucy = watchedLucy(made)
	S.current = lucy
	S.packages()
	local env =
		{ Lucy = lucy, app = S.m.app, parent = slot, scene = { gui = slot, app = S.m.app }, game = S.game() }
	for k, v in fixtures(lucy, slot) do
		env[k] = v
	end
	S.m.app.state:set("topDancers", {
		{ userId = 2, name = "Nova" },
		{ userId = 3, name = "Kai" },
		{ userId = 4, name = "Juno" },
	})
	setmetatable(env, { __index = getfenv(1) })
	setfenv(fn, env)
	-- Inside the preview's scope, so composables have an owner.
	local done, ok, e = false, true, nil
	local thread = task.spawn(function()
		ok, e = pcall(function()
			S.m._scope:run(fn)
		end)
		done = true
	end)
	local started = os.clock()
	while not done and os.clock() - started < 2 do
		task.wait(0.05)
	end
	if not done then
		pcall(task.cancel, thread)
		return "timeout: the example waits on something that never comes in edit mode"
	end
	if not ok then
		return tostring(e)
	end
	local order = 0
	for _, handle in made do
		local inst = instanceOf(handle)
		if inst and inst.Parent == nil and inst:IsA("GuiObject") then
			order += 1
			inst.LayoutOrder = order
			inst.Parent = slot
		end
	end
	return nil
end

-- A stand-in for a client in edit mode: Players.LocalPlayer with the Club Lucy
-- attributes, and remotes that answer nothing, so whole client scripts run.
function S.game()
	if S._game then
		return S._game
	end
	local fakePlayer = S._player
	if not fakePlayer then
		fakePlayer = Instance.new("Configuration")
		fakePlayer.Name = "DJLucy"
		for k, v in { Hype = 72, Combo = 8, Coins = 1250, Level = 12 } do
			fakePlayer:SetAttribute(k, v)
		end
		S._player = fakePlayer
	end
	local playerProxy = setmetatable({ DisplayName = "DJ Lucy", Name = "DJLucy", UserId = 1 }, {
		__index = function(_, k)
			local v = fakePlayer[k]
			if type(v) == "function" then
				return function(_, ...)
					return v(fakePlayer, ...)
				end
			end
			return v
		end,
	})
	local remote = {
		InvokeServer = function()
			return { theme = "dark", music = 80, sfx = 60, crowd = 40, lights = true }
		end,
		FireServer = function() end,
		OnClientEvent = {
			Connect = function()
				return { Disconnect = function() end }
			end,
		},
	}
	local function service(real, extra)
		return setmetatable(extra, {
			__index = function(_, k)
				local v = real[k]
				if type(v) == "function" then
					return function(_, ...)
						return v(real, ...)
					end
				end
				return v
			end,
		})
	end
	local RS = game:GetService("ReplicatedStorage")
	local services = {
		Players = service(game:GetService("Players"), { LocalPlayer = playerProxy }),
		ReplicatedStorage = service(RS, {
			WaitForChild = function(_, name)
				-- Packages is real (Lucy); anything else a client waits for is a remote.
				if name == "Packages" then
					return RS:WaitForChild(name)
				end
				return remote
			end,
		}),
	}
	S._game = setmetatable({
		GetService = function(_, name)
			return services[name] or game:GetService(name)
		end,
	}, {
		__index = function(_, k)
			return services[k] or game[k]
		end,
	})
	return S._game
end

-- ReplicatedStorage.Packages.Lucy, as games require it, handing out the watched Lucy.
function S.packages()
	local RS = ReplicatedStorage
	local folder = RS:FindFirstChild("Packages")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Packages"
		folder.Parent = RS
		S._madePackages = folder
	end
	if not folder:FindFirstChild("Lucy") then
		local m = Instance.new("ModuleScript")
		m.Name = "Lucy"
		m.Source =
			"return setmetatable({}, { __index = function(_, k) return _G.LucyDocPictures.current[k] end })"
		m.Parent = folder
	end
end

local function newSlot(i)
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. i
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(S.SLOT, 0)
	slot.AutomaticSize = Enum.AutomaticSize.Y
	slot.Position = UDim2.fromOffset(40, 40)
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 12)
	list.Parent = slot
	slot.Parent = S.m.target
	return slot
end

local function fmt(r)
	return string.format("%.1f,%.1f,%.1f,%.1f", r[1], r[2], r[3], r[4])
end

-- Runs one block alone and reports: ok/err, ink size, whether it opened an overlay.
function S.probe(code, theme)
	S.mount(theme or "dark")
	local slot = newSlot(1)
	local err = run(code, slot)
	task.wait(0.35)
	local screen = workspace.CurrentCamera.ViewportSize
	local own = S.ink(slot, screen)
	local over
	for _, g in overlayGuis() do
		over = union(over, S.ink(g, screen))
	end
	return { err = err, own = own and fmt(own), over = over and fmt(over) }
end

function S.probeRange(i0, i1)
	S.list = S.list or S.load("blocks.json")
	local out = {}
	for i = i0, math.min(i1, #S.list) do
		local b = S.list[i]
		local ok, res = pcall(S.probe, b.code)
		if not ok then
			res = { err = "probe: " .. tostring(res) }
		end
		table.insert(
			out,
			string.format(
				"%d|%s#%d|%s|%s|%s",
				i,
				b.file,
				b.index,
				res.err and res.err:gsub("\n", " "):sub(1, 90) or "",
				res.own or "",
				res.over or ""
			)
		)
	end
	S.clear()
	return table.concat(out, "\n")
end

-- Draws several examples on one screen. items: { {name=, code=}, ... }
-- Returns one line per item: name box vp=W,H (or name ERR message).
function S.sheet(items, theme)
	if type(items[1]) == "string" then
		local named = {}
		for i, n in items do
			named[i] = S.byName[n]
		end
		items = named
	end
	S.mount(theme)
	local screen = workspace.CurrentCamera.ViewportSize
	local slots, errs = {}, {}
	for i, item in items do
		slots[i] = newSlot(i)
		errs[i] = run(item.code, slots[i], item["then"])
	end
	task.wait(0.35)
	-- Shelf-pack the ink boxes left to right, top to bottom.
	local x, y, row = S.MARGIN, S.MARGIN, 0
	local placed = {}
	for i, slot in slots do
		local r = S.ink(slot, screen)
		if r and not errs[i] then
			local w, h = r[3] - r[1], r[4] - r[2]
			if x + w > screen.X - S.MARGIN and x > S.MARGIN then
				x, y, row = S.MARGIN, y + row + S.GAP, 0
			end
			if y + h > screen.Y - S.MARGIN and (x > S.MARGIN or y > S.MARGIN) then
				slot.Visible = false
				errs[i] = "LATER"
				continue
			end
			local scale = slot.AbsoluteSize.X / S.SLOT
			local p = slot.Position
			slot.Position = UDim2.fromOffset(p.X.Offset + (x - r[1]) / scale, p.Y.Offset + (y - r[2]) / scale)
			placed[i] = true
			x = x + w + S.GAP
			row = math.max(row, h)
		else
			slot.Visible = false
		end
	end
	task.wait(0.2)
	local out = {}
	for i, item in items do
		if errs[i] == "LATER" then
			table.insert(out, item.name .. " LATER")
		elseif errs[i] then
			table.insert(out, item.name .. " ERR " .. errs[i]:gsub("\n", " "):sub(1, 120))
		elseif not placed[i] then
			table.insert(out, item.name .. " EMPTY")
		else
			local r = S.ink(slots[i], screen)
			local fits = r[3] <= screen.X and r[4] <= screen.Y
			table.insert(
				out,
				string.format(
					"%s %s vp=%d,%d%s",
					item.name,
					fmt(r),
					screen.X,
					screen.Y,
					fits and "" or " OVERFLOW"
				)
			)
		end
	end
	return table.concat(out, "\n")
end

-- Draws one example alone (it may open overlays); the box covers everything it drew.
function S.solo(item, theme)
	S.mount(theme)
	local screen = workspace.CurrentCamera.ViewportSize
	local slot = newSlot(1)
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.fromScale(0.5, 0.5)
	local err = run(item.code, slot, item["then"])
	task.wait(0.5)
	if err then
		return item.name .. " ERR " .. err
	end
	local r = S.ink(slot, screen)
	for _, g in overlayGuis() do
		r = union(r, S.ink(g, screen))
	end
	if not r then
		return item.name .. " EMPTY"
	end
	return string.format("%s %s vp=%d,%d", item.name, fmt(r), screen.X, screen.Y)
end

-- A whole client script, shown full screen.
function S.screen(item, theme)
	S.mount(theme)
	local screen = workspace.CurrentCamera.ViewportSize
	local slot = newSlot(1)
	local err = run(item.code, slot, item["then"])
	task.wait(0.8)
	if err then
		return item.name .. " ERR " .. err
	end
	return string.format("%s 0,0,%d,%d vp=%d,%d", item.name, screen.X, screen.Y, screen.X, screen.Y)
end

function S.examples(file)
	S.byName = {}
	S.order = {}
	for _, e in S.load(file) do
		S.byName[e.name] = e
		table.insert(S.order, e.name)
	end
	return #S.order
end

-- One example by name, the way its marker asks.
function S.one(name, theme)
	local e = S.byName[name]
	if e.screen then
		return S.screen(e, theme)
	end
	return S.solo(e, theme)
end

-- What the viewport shows now, as an EditableImage (Studio captures at its own
-- pixel density, twice the viewport on a Retina screen).
local function screenshot(): EditableImage
	local id
	CaptureService:CaptureScreenshot(function(contentId)
		id = contentId
	end)
	local started = os.clock()
	while not id and os.clock() - started < 5 do
		task.wait(0.05)
	end
	assert(id, "the screen capture never came")
	return AssetService:CreateEditableImageAsync(Content.fromUri(id))
end

-- Captures the viewport and sends each example's area (its box, padded) to the
-- server, which writes the pair once both themes are in.
function S.capture(theme: string, lines: string): string
	local image = screenshot()
	local size = image.Size
	local out = {}
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, err = pcall(function()
		for _, line in string.split(lines, "\n") do
			local name, a, b, c, d, e, f =
				line:match("^(%S+) ([%d.]+),([%d.]+),([%d.]+),([%d.]+) vp=(%d+),(%d+)")
			if name then
				local x0, y0, x1, y1 =
					tonumber(a) :: number, tonumber(b) :: number, tonumber(c) :: number, tonumber(d) :: number
				local vw, vh = tonumber(e) :: number, tonumber(f) :: number
				local scale = size.X / vw
				local whole = x0 <= 0 and y0 <= 0 and x1 >= vw and y1 >= vh
				local ax0, ay0, ax1, ay1 = 0, 0, size.X, size.Y
				if not whole then
					ax0 = math.max(0, math.floor(x0 * scale) - S.PAD)
					ay0 = math.max(0, math.floor(y0 * scale) - S.PAD)
					ax1 = math.min(size.X, math.ceil(x1 * scale) + S.PAD)
					ay1 = math.min(size.Y, math.ceil(y1 * scale) + S.PAD)
				end
				local w, h = ax1 - ax0, ay1 - ay0
				-- Roblox posts at most 1 MB, so the rows go in strips.
				local strip = math.max(1, math.floor(900 * 1024 / (w * 4)))
				local reply = ""
				for y = 0, h - 1, strip do
					local rows = math.min(strip, h - y)
					local pixels = image:ReadPixelsBuffer(Vector2.new(ax0, ay0 + y), Vector2.new(w, rows))
					local url =
						`{S.URL}pixels?name={name}&theme={theme}&w={w}&h={h}&y={y}&whole={whole and 1 or 0}`
					reply = HttpService:PostAsync(
						url,
						buffer.tostring(pixels),
						Enum.HttpContentType.TextPlain,
						true
					)
				end
				table.insert(out, reply)
			end
		end
	end)
	HttpService.HttpEnabled = was
	image:Destroy()
	assert(ok, err)
	return table.concat(out, "\n")
end

-- Every queued example, dark then light, captured and sent. Progress goes to S.log.
function S.run(): string
	S.log = {}
	while true do
		local dark = S.next("dark")
		if dark == "done" then
			break
		end
		task.wait(0.2)
		table.insert(S.log, S.capture("dark", dark))
		local light = S.again("light")
		task.wait(0.2)
		table.insert(S.log, S.capture("light", light))
	end
	return table.concat(S.log, "\n")
end

-- A private copy of Lucy, with the docs icon sheet registered, so the place's own
-- Lucy (and its icon registry) is never touched.
local function freshLucy()
	for _, c in ReplicatedStorage:GetChildren() do
		if c.Name == "DocPictures_Lucy" then
			c:Destroy()
		end
	end
	local clone = ReplicatedStorage.Lucy:Clone()
	clone.Name = "DocPictures_Lucy"
	clone.Archivable = false
	clone.Parent = ReplicatedStorage
	local Lucy = require(clone)
	local icons = ReplicatedStorage:FindFirstChild("LucyExamples")
	icons = icons and icons:FindFirstChild("DocIcons")
	assert(icons, "ReplicatedStorage.LucyExamples.DocIcons is missing: is Rojo serving test.project.json?")
	Lucy.Icon.register(require(icons:Clone()))
	return Lucy
end

-- Loads the examples and gets ready. Call again after Lucy changes to pick it up.
function S.start()
	S.stop()
	_G.LucyDocPictures = S
	S._before = {}
	for _, g in StarterGui:GetChildren() do
		S._before[g] = true
	end
	S.Lucy = freshLucy()
	local n = S.examples("examples.json")
	S.queue = table.clone(S.order)
	S.lastSet = nil
	return `{n} examples`
end

-- Inline examples share a screen; solo and screen ones get one each.
local function alone(name)
	local e = S.byName[name]
	return e.solo or e.screen
end

-- Draws the next screenful from the queue in `theme`.
function S.next(theme)
	assert(S.queue, "call start() first")
	if #S.queue == 0 then
		return "done"
	end
	local first = table.remove(S.queue, 1)
	if alone(first) then
		S.lastSet = { first }
		return S.one(first, theme)
	end
	local set = { first }
	while #S.queue > 0 and #set < 16 and not alone(S.queue[1]) do
		table.insert(set, table.remove(S.queue, 1))
	end
	local out = S.sheet(set, theme)
	-- What did not fit goes back to the front of the queue.
	local drawn, later = {}, {}
	for _, line in string.split(out, "\n") do
		local name, rest = line:match("^(%S+) (.*)$")
		if rest == "LATER" then
			table.insert(later, name)
		else
			table.insert(drawn, name)
		end
	end
	for i = #later, 1, -1 do
		table.insert(S.queue, 1, later[i])
	end
	S.lastSet = drawn
	return out
end

-- The examples the last next() drew, in another theme, at the same places.
function S.again(theme)
	assert(S.lastSet, "nothing drawn yet")
	if #S.lastSet == 1 and alone(S.lastSet[1]) then
		return S.one(S.lastSet[1], theme)
	end
	return S.sheet(S.lastSet, theme)
end

-- Queues just these examples (by name), to redraw a few pictures.
function S.only(names)
	for _, name in names do
		assert(S.byName[name], "no marked example named " .. tostring(name))
	end
	S.queue = table.clone(names)
	return `{#names} queued`
end

-- Takes away everything the renderer made: the preview, its guis and any the
-- examples left (Devtools and actions guis too), the copy of Lucy, the Packages
-- stand-in. The place is as it was before start().
function S.stop()
	S.clear()
	if S._before then
		for _, g in StarterGui:GetChildren() do
			if not S._before[g] then
				g:Destroy()
			end
		end
	end
	for _, c in ReplicatedStorage:GetChildren() do
		if c.Name == "DocPictures_Lucy" then
			c:Destroy()
		end
	end
	if S._madePackages then
		S._madePackages:Destroy()
		S._madePackages = nil
	end
	S._before, S._game, S._player, S.queue, S.lastSet = nil, nil, nil, nil, nil
	if _G.LucyDocPictures == S then
		_G.LucyDocPictures = nil
	end
	return "stopped"
end

return S
