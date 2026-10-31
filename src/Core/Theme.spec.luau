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
			local derive = theme.folder.Design:FindFirstChild("ActiveDensity")
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

		it("swaps the design sheet's derive and fires Changed", function()
			theme = Theme.new(config)
			local changedTo
			theme.Changed:Connect(function(name)
				changedTo = name
			end)
			theme:set("dark")
			expect(theme:get()).to.equal("dark")
			expect(changedTo).to.equal("dark")
			expect(theme:resolve("Primary")).to.equal(hex("0000ff"))
			local derive = theme.folder.Design:FindFirstChildOfClass("StyleDerive")
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
			for _, child in theme.folder.Design:GetChildren() do
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
			Harness.flush()
			expect(Harness.colorEq(Harness.styled(frame, "BackgroundColor3"), hex("0000ff"))).to.equal(true)
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
