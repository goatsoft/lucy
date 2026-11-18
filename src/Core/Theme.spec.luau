return function()
	local Theme = require(script.Parent.Theme)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local hex = Color3.fromHex
	local config = {
		name = "LucyTest_Theme",
		primitives = { Red = hex("ff0000"), Blue = hex("0000ff"), Gap8 = UDim.new(0, 8) },
		themes = {
			light = { Primary = "$Red", Gap = "$Gap8" },
			dark = { Primary = "$Blue", Gap = "$Gap8" },
		},
		default = "light",
		baseRules = false,
	}

	local theme
	afterEach(function()
		if theme then
			theme:destroy()
			theme = nil
		end
	end)

	describe("building sheets", function()
		it("creates a tokens sheet, a sheet per theme and a design sheet", function()
			theme = Theme.new(config)
			local folder = theme.folder
			expect(folder:FindFirstChild("Tokens"):IsA("StyleSheet")).to.equal(true)
			expect(folder:FindFirstChild("Theme_light"):IsA("StyleSheet")).to.equal(true)
			expect(folder:FindFirstChild("Theme_dark"):IsA("StyleSheet")).to.equal(true)
			expect(folder:FindFirstChild("Design"):IsA("StyleSheet")).to.equal(true)
		end)

		it("writes primitives and theme aliases as attributes", function()
			theme = Theme.new(config)
			expect(theme.folder.Tokens:GetAttribute("Red")).to.equal(hex("ff0000"))
			expect(theme.folder.Theme_dark:GetAttribute("Primary")).to.equal("$Blue")
		end)

		it("refuses themes with mismatched keys", function()
			expect(function()
				Theme.new({
					primitives = {},
					themes = { a = { X = 1 }, b = { Y = 1 } },
				})
			end).to.throw()
		end)
	end)

	describe("derived tokens", function()
		it("computes mix/over tokens per theme into colours", function()
			local Tokens = require(script.Parent.Tokens)
			theme = Theme.new({
				name = "LucyTest_Derived",
				primitives = config.primitives,
				themes = {
					light = { Bg = "$Red", Edge = Tokens.over("$Blue", "$Bg", 0.5) },
					dark = { Bg = "$Blue", Edge = Tokens.over("$Red", "$Bg", 0.5) },
				},
				default = "light",
				baseRules = false,
			})
			local edge = theme.folder.Theme_light:GetAttribute("Edge")
			expect(typeof(edge)).to.equal("Color3")
			expect(Harness.colorEq(edge, Color3.new(0.5, 0, 0.5))).to.equal(true)
		end)
	end)

	describe("densities", function()
		it("builds a sheet per density and derives the active one", function()
			theme = Theme.new(config)
			expect(theme:getDensity()).to.equal("default")
			expect(theme.folder:FindFirstChild("Density_touch")).to.be.ok()
			expect(theme:resolve("ControlMd").Y.Offset).to.equal(36)
		end)

		it("switches density and fires DensityChanged", function()
			theme = Theme.new(config)
			local fired
			theme.DensityChanged:Connect(function(name)
				fired = name
			end)
			theme:setDensity("touch")
			expect(fired).to.equal("touch")
			expect(theme:resolve("ControlMd").Y.Offset).to.equal(44)
			local derive = theme.folder.Values:FindFirstChild("ActiveDensity")
			expect(derive.StyleSheet).to.equal(theme.folder.Density_touch)
		end)
	end)

	describe("text growth", function()
		local function half(size: number): number
			return size // 2
		end
		local function height(token: string): number
			return theme:resolve(token).Y.Offset
		end

		it("grows each control by what its text grows", function()
			theme = Theme.new(config)
			theme:setTextGrowth(half)
			expect(height("ControlSm")).to.equal(32 + 6) -- TextXs 12
			expect(height("ControlMd")).to.equal(36 + 7) -- TextSm 14
			expect(height("ControlLg")).to.equal(40 + 8) -- TextBase 16
			expect(height("ControlXl")).to.equal(48 + 9) -- TextLg 18
		end)

		it("leaves icon buttons alone: they have no text", function()
			theme = Theme.new(config)
			theme:setTextGrowth(half)
			expect(theme:resolve("ControlIcon")).to.equal(UDim2.fromOffset(36, 36))
		end)

		it("applies to every density, and nil takes it off", function()
			theme = Theme.new(config)
			theme:setTextGrowth(half)
			theme:setDensity("tv")
			expect(height("ControlMd")).to.equal(52 + 8) -- tv TextSm is 16
			theme:setTextGrowth(nil)
			expect(height("ControlMd")).to.equal(52)
		end)

		it("fires MetricsChanged", function()
			theme = Theme.new(config)
			local fired = 0
			theme.MetricsChanged:Connect(function()
				fired += 1
			end)
			theme:setTextGrowth(half)
			expect(fired).to.equal(1)
		end)
	end)

	describe("transparency", function()
		local seeThrough = {
			name = "LucyTest_ThemeSeeThrough",
			primitives = config.primitives,
			themes = {
				light = { Primary = "$Red", OverlayTransparency = 0.5 },
				dark = { Primary = "$Blue", OverlayTransparency = 0.3 },
			},
			default = "light",
			baseRules = false,
		}
		local function near(a: number, b: number): boolean
			return math.abs(a - b) < 1e-6
		end

		it("multiplies every see-through token by the scale, in every theme", function()
			theme = Theme.new(seeThrough)
			theme:setTransparency(0.5)
			expect(near(theme:resolve("OverlayTransparency"), 0.25)).to.equal(true)
			theme:set("dark")
			expect(near(theme:resolve("OverlayTransparency"), 0.15)).to.equal(true)
		end)

		it("makes them solid at 0, and nil puts the theme's own values back", function()
			theme = Theme.new(seeThrough)
			theme:setTransparency(0)
			expect(theme:resolve("OverlayTransparency")).to.equal(0)
			theme:setTransparency(nil)
			expect(near(theme:resolve("OverlayTransparency"), 0.5)).to.equal(true)
		end)
	end)

	describe("base rules", function()
		it("are added by default", function()
			theme = Theme.new({ name = "LucyTest_Base" })
			expect(theme:hasRules("uikit-base")).to.equal(true)
		end)

		it("remove default borders and button tinting inside linked guis", function()
			theme = Theme.new({ name = "LucyTest_Base" })
			local gui = Instance.new("ScreenGui")
			gui.Name = "LucyTest_BaseGui"
			theme:link(gui)
			local frame = Instance.new("Frame")
			frame.Parent = gui
			local button = Instance.new("TextButton")
			button.Parent = gui
			gui.Parent = Harness.guiParent()
			Harness.flush()
			expect(Harness.styled(frame, "BorderSizePixel")).to.equal(0)
			expect(Harness.styled(button, "AutoButtonColor")).to.equal(false)
			gui:Destroy()
		end)
	end)

	describe("switching", function()
		it("starts on the default theme and resolves aliases", function()
			theme = Theme.new(config)
			expect(theme:get()).to.equal("light")
			expect(theme:resolve("Primary")).to.equal(hex("ff0000"))
			expect(theme:resolve("Gap")).to.equal(UDim.new(0, 8))
		end)

		it("swaps the values sheet's derive and fires Changed", function()
			theme = Theme.new(config)
			local changedTo
			theme.Changed:Connect(function(name)
				changedTo = name
			end)
			theme:set("dark")
			expect(theme:get()).to.equal("dark")
			expect(changedTo).to.equal("dark")
			expect(theme:resolve("Primary")).to.equal(hex("0000ff"))
			local derive = theme.folder.Values:FindFirstChild("ActiveTheme")
			expect(derive.StyleSheet).to.equal(theme.folder.Theme_dark)
		end)

		it("errors on an unknown theme", function()
			theme = Theme.new(config)
			expect(function()
				theme:set("sepia")
			end).to.throw()
		end)
	end)

	describe("rules", function()
		it("adds rules once per key", function()
			theme = Theme.new(config)
			local rules = { { selector = ".x", properties = { BackgroundColor3 = "$Primary" } } }
			theme:addRules("x", rules)
			theme:addRules("x", rules)
			local count = 0
			for _, child in theme.folder.Game:GetChildren() do
				if child:IsA("StyleRule") and child.Selector == ".x" then
					count += 1
				end
			end
			expect(count).to.equal(1)
			expect(theme:hasRules("x")).to.equal(true)
		end)

		it("styles a linked, tagged frame and restyles on theme switch", function()
			theme = Theme.new(config)
			theme:addRules("swatch", {
				{ selector = ".test-swatch", properties = { BackgroundColor3 = "$Primary" } },
			})
			local gui = Instance.new("ScreenGui")
			gui.Name = "LucyTest_ThemeGui"
			theme:link(gui)
			local frame = Instance.new("Frame")
			frame:AddTag("test-swatch")
			frame.Parent = gui
			gui.Parent = Harness.guiParent()

			Harness.flush()
			expect(Harness.colorEq(Harness.styled(frame, "BackgroundColor3"), hex("ff0000"))).to.equal(true)

			theme:set("dark")
			expect(Harness.waitFor(function()
				return Harness.colorEq(Harness.styled(frame, "BackgroundColor3"), hex("0000ff"))
			end)).to.equal(true)
			gui:Destroy()
		end)

		it("lets higher priority rules win", function()
			theme = Theme.new(config)
			theme:addRules("prio", {
				{ selector = ".test-prio", priority = 0, properties = { BackgroundColor3 = "$Primary" } },
				{
					selector = ".test-prio.test-alt",
					priority = 10,
					properties = { BackgroundColor3 = Color3.new(0, 1, 0) },
				},
			})
			local gui = Instance.new("ScreenGui")
			gui.Name = "LucyTest_PrioGui"
			theme:link(gui)
			local frame = Instance.new("Frame")
			frame:AddTag("test-prio")
			frame:AddTag("test-alt")
			frame.Parent = gui
			gui.Parent = Harness.guiParent()
			Harness.flush()
			expect(Harness.colorEq(Harness.styled(frame, "BackgroundColor3"), Color3.new(0, 1, 0))).to.equal(
				true
			)
			gui:Destroy()
		end)
	end)

	-- A linked gui with one frame tagged `tag`, styled by `sheet`; returns the frame and a cleanup
	local function probe(sheet: StyleSheet, tag: string): (Frame, () -> ())
		local gui = Instance.new("ScreenGui")
		gui.Name = "LucyTest_LayerGui"
		local link = Instance.new("StyleLink")
		link.StyleSheet = sheet
		link.Parent = gui
		local frame = Instance.new("Frame")
		frame:AddTag(tag)
		frame.Parent = gui
		gui.Parent = Harness.guiParent()
		Harness.flush()
		return frame, function()
			gui:Destroy()
		end
	end
	local RED, BLUE = Color3.new(1, 0, 0), Color3.new(0, 0, 1)
	local function colourOf(frame: Frame): Color3
		return Harness.styled(frame, "BackgroundColor3")
	end

	-- What Lucy's layers rest on and Roblox does not document (ADR 0052): a change here fails the
	-- suite instead of a game's look
	describe("the engine", function()
		local made: { Instance } = {}
		afterEach(function()
			for _, instance in made do
				instance:Destroy()
			end
			table.clear(made)
		end)
		local function sheet(): StyleSheet
			local s = Instance.new("StyleSheet")
			s.Parent = Harness.guiParent()
			table.insert(made, s)
			return s
		end
		local function derive(from: StyleSheet, to: StyleSheet)
			local d = Instance.new("StyleDerive")
			d.StyleSheet = to
			d.Parent = from
		end
		local function rule(s: StyleSheet, selector: string, colour: any, priority: number?)
			local r = Instance.new("StyleRule")
			r.Selector = selector
			r.Priority = priority or 0
			r:SetProperties({ BackgroundColor3 = colour })
			r.Parent = s
		end

		it("lets a sheet's own rules beat a derived sheet's, whatever their Priority", function()
			local low, high = sheet(), sheet()
			rule(low, ".probe-layer", RED, 100)
			derive(high, low)
			rule(high, ".probe-layer", BLUE, 0)
			local frame, done = probe(high, "probe-layer")
			expect(Harness.colorEq(colourOf(frame), BLUE)).to.equal(true)
			done()
		end)

		it("lets the rule added later win a tie, with no specificity", function()
			local s = sheet()
			rule(s, "Frame.probe-tie", RED, 0)
			rule(s, ".probe-tie", BLUE, 0)
			local frame, done = probe(s, "probe-tie")
			expect(Harness.colorEq(colourOf(frame), BLUE)).to.equal(true)
			done()
		end)

		it("resolves tokens through derives at any depth", function()
			local tokens, middle, top = sheet(), sheet(), sheet()
			tokens:SetAttribute("ProbeColour", BLUE)
			derive(middle, tokens)
			derive(top, middle)
			rule(top, ".probe-token", "$ProbeColour")
			local frame, done = probe(top, "probe-token")
			expect(Harness.colorEq(colourOf(frame), BLUE)).to.equal(true)
			done()
		end)
	end)

	describe("layers (ADR 0052)", function()
		it("stacks Values, Lucy, Game, Fixed and Design, each deriving the one below", function()
			theme = Theme.new(config)
			local folder = theme.folder
			local function below(name: string): Instance?
				local d = folder[name]:FindFirstChildOfClass("StyleDerive")
				return d and d.StyleSheet
			end
			expect(below("Design")).to.equal(folder.Fixed)
			expect(below("Fixed")).to.equal(folder.Game)
			expect(below("Game")).to.equal(folder.Lucy)
			expect(below("Lucy")).to.equal(folder.Values)
			expect(theme.design).to.equal(folder.Design)
		end)

		it("puts a game's rules over Lucy's, whatever Lucy's Priority", function()
			theme = Theme.new(config)
			theme:addRules("lucy-probe", {
				{ selector = ".probe-game", priority = 100, properties = { BackgroundColor3 = RED } },
			}, { layer = "lucy" })
			theme:addRules("game-probe", {
				{ selector = ".probe-game", priority = 0, properties = { BackgroundColor3 = BLUE } },
			})
			local frame, done = probe(theme.design, "probe-game")
			expect(Harness.colorEq(colourOf(frame), BLUE)).to.equal(true)
			done()
		end)

		it("puts live rules over the game's, in the small top sheet", function()
			theme = Theme.new(config)
			theme:addRules("game-probe", {
				{ selector = ".probe-live", priority = 100, properties = { BackgroundColor3 = RED } },
			})
			theme:addRules("live-probe", {
				{ selector = ".probe-live", properties = { BackgroundColor3 = BLUE } },
			}, { layer = "live" })
			expect(theme.folder.Design:FindFirstChildOfClass("StyleRule")).to.be.ok()
			local frame, done = probe(theme.design, "probe-live")
			expect(Harness.colorEq(colourOf(frame), BLUE)).to.equal(true)
			theme:removeRules("live-probe")
			expect(Harness.waitFor(function()
				return Harness.colorEq(colourOf(frame), RED)
			end)).to.equal(true)
			done()
		end)

		it("lets a game rule use the theme's tokens from its layer", function()
			theme = Theme.new(config)
			theme:addRules("game-token", {
				{ selector = ".probe-game-token", properties = { BackgroundColor3 = "$Primary" } },
			})
			local frame, done = probe(theme.design, "probe-game-token")
			expect(Harness.colorEq(colourOf(frame), hex("ff0000"))).to.equal(true)
			theme:set("dark")
			expect(Harness.waitFor(function()
				return Harness.colorEq(colourOf(frame), hex("0000ff"))
			end)).to.equal(true)
			done()
		end)

		it("puts a fixed rule (what a component is, not its look) over the game's", function()
			theme = Theme.new(config)
			theme:addRules("lucy-fixed", {
				{ selector = ".probe-fixed", fixed = true, properties = { BackgroundColor3 = BLUE } },
			}, { layer = "lucy" })
			theme:addRules("game-look", {
				{ selector = ".probe-fixed", priority = 1000, properties = { BackgroundColor3 = RED } },
			})
			expect(theme.folder.Fixed:FindFirstChildOfClass("StyleRule")).to.be.ok()
			local frame, done = probe(theme.design, "probe-fixed")
			expect(Harness.colorEq(colourOf(frame), BLUE)).to.equal(true)
			done()
		end)

		it("keeps an untinted icon's own colours and a gradient host's white under a game's look", function()
			local Lucy = require(script.Parent.Parent)
			local app, cleanup = Harness.app()
			app.theme:addRules("game-tints", {
				{ selector = ".ui-icon", priority = 500, properties = { ImageColor3 = RED } },
				{ selector = ".probe-card", priority = 500, properties = { BackgroundColor3 = RED } },
			})
			local gui = Harness.mount(app)
			local icon = Instance.new("ImageLabel")
			icon:AddTag("ui-icon")
			icon:AddTag("ui-icon-untinted")
			icon.Parent = gui
			local card = Instance.new("Frame")
			card:AddTag("probe-card")
			card.Parent = gui
			Lucy.Gradient.new({ app = app, gradient = "Primary", Parent = card })
			Harness.flush()
			expect(Harness.colorEq(Harness.styled(icon, "ImageColor3"), Color3.new(1, 1, 1))).to.equal(true)
			expect(Harness.colorEq(Harness.styled(card, "BackgroundColor3"), Color3.new(1, 1, 1))).to.equal(
				true
			)
			cleanup()
		end)

		it("refuses a layer it does not have", function()
			theme = Theme.new(config)
			expect(function()
				theme:addRules("nowhere", {}, { layer = "top" })
			end).to.throw()
		end)
	end)

	describe("declared rules (ADR 0052)", function()
		afterEach(function()
			Theme._forget("probe-declared-a")
			Theme._forget("probe-declared-b")
		end)

		it("builds every group declared so far into the Lucy layer, in declaration order", function()
			Theme.declare("probe-declared-a", {
				{ selector = ".probe-declared", properties = { BackgroundColor3 = RED } },
			})
			Theme.declare("probe-declared-b", {
				{ selector = ".probe-declared", properties = { BackgroundColor3 = BLUE } },
			})
			theme = Theme.new(config)
			expect(theme:hasRules("probe-declared-a") and theme:hasRules("probe-declared-b")).to.equal(true)
			local inLucy = 0
			for _, child in theme.folder.Lucy:GetChildren() do
				if child:IsA("StyleRule") and child.Selector == ".probe-declared" then
					inLucy += 1
				end
			end
			expect(inLucy).to.equal(2)
			local frame, done = probe(theme.design, "probe-declared")
			expect(Harness.colorEq(colourOf(frame), BLUE)).to.equal(true)
			done()
		end)

		it("adds nothing more when a declared group is added again", function()
			local rules = { { selector = ".probe-declared", properties = { BackgroundColor3 = RED } } }
			Theme.declare("probe-declared-a", rules)
			theme = Theme.new(config)
			local before = #theme.folder.Lucy:GetChildren()
			theme:addRules("probe-declared-a", rules, { layer = "lucy" })
			expect(#theme.folder.Lucy:GetChildren()).to.equal(before)
		end)

		it("has every Lucy component's rules from the start, so mounting adds none", function()
			local Lucy = require(script.Parent.Parent)
			local app, cleanup = Harness.app()
			local function ruleCount(): number
				local n = 0
				for _, layer in { "Lucy", "Game", "Design" } do
					for _, child in app.theme.folder[layer]:GetChildren() do
						if child:IsA("StyleRule") then
							n += 1
						end
					end
				end
				return n
			end
			for _, key in
				{ "button", "toggle", "select", "switch", "dialog", "sheet", "menu", "overlay", "toaster" }
			do
				if not app.theme:hasRules(key) then
					error(`no "{key}" rules at start`, 0)
				end
			end
			local before = ruleCount()
			local gui = Harness.mount(app)
			Lucy.ToggleGroup.new({ app = app, items = { "A", "B" }, Parent = gui })
			Lucy.Select.new({ app = app, items = { "A", "B" }, Parent = gui })
			Lucy.Switch.new({ app = app, Parent = gui })
			Lucy.Button.new({ app = app, text = "Go", Parent = gui })
			expect(ruleCount()).to.equal(before)
			cleanup()
		end)
	end)

	it("draws every focus ring inside its element, never past its edge", function()
		local found = 0
		for _, rule in Theme.baseRules do
			local props = rule.properties or {}
			if props.Thickness == "$FocusRing" then
				found += 1
				expect(props.BorderStrokePosition).to.equal(Enum.BorderStrokePosition.Inner)
			end
		end
		expect(found >= 2).to.equal(true)
	end)

	it("draws every border inside its element, so a scroll area never clips one", function()
		-- Like CSS's border-box: an Outer stroke draws past the element's edge, where
		-- a ScrollingFrame or a tight row cuts it off.
		local checked = 0
		local function check(rule, owner: string)
			local selector: string = rule.selector
			if selector:sub(-10) == "::UIStroke" and rule.properties.Thickness ~= nil then
				checked += 1
				if rule.properties.BorderStrokePosition ~= Enum.BorderStrokePosition.Inner then
					error(`{owner} {selector} draws its border outside`, 0)
				end
			end
		end
		for _, rule in Theme.baseRules do
			check(rule, "Theme")
		end
		for _, module in script.Parent.Parent.Components:GetChildren() do
			if module:IsA("ModuleScript") and not module.Name:match("%.spec$") then
				local ok, component = pcall(require, module)
				if ok and type(component) == "table" and type(rawget(component, "rules")) == "table" then
					for _, rule in component.rules do
						check(rule, module.Name)
					end
				end
			end
		end
		expect(checked > 10).to.equal(true)
	end)
end
