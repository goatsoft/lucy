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
end
