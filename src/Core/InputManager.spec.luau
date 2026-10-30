return function()
	local InputManager = require(script.Parent.InputManager)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	describe("modeFor", function()
		it("classifies input types", function()
			expect(InputManager.modeFor(Enum.UserInputType.MouseMovement)).to.equal("mouse")
			expect(InputManager.modeFor(Enum.UserInputType.MouseButton1)).to.equal("mouse")
			expect(InputManager.modeFor(Enum.UserInputType.Keyboard)).to.equal("keyboard")
			expect(InputManager.modeFor(Enum.UserInputType.Gamepad1)).to.equal("gamepad")
			expect(InputManager.modeFor(Enum.UserInputType.Touch)).to.equal("touch")
			expect(InputManager.modeFor(Enum.UserInputType.Focus)).to.equal(nil)
		end)
	end)

	describe("deviceFor", function()
		it("treats the 10-foot interface as console", function()
			expect(
				InputManager.deviceFor({ tenFoot = true, gamepad = true, viewport = Vector2.new(1920, 1080) })
			).to.equal("console")
		end)

		it("splits touch-only screens into mobile and tablet", function()
			expect(InputManager.deviceFor({ touch = true, viewport = Vector2.new(844, 390) })).to.equal(
				"mobile"
			)
			expect(InputManager.deviceFor({ touch = true, viewport = Vector2.new(1180, 820) })).to.equal(
				"tablet"
			)
		end)

		it("calls anything with a keyboard or mouse a desktop", function()
			expect(
				InputManager.deviceFor({ keyboard = true, mouse = true, viewport = Vector2.new(1920, 1080) })
			).to.equal("desktop")
			expect(
				InputManager.deviceFor({ touch = true, keyboard = true, viewport = Vector2.new(1280, 800) })
			).to.equal("desktop")
		end)
	end)

	describe("densityFor", function()
		it("maps devices to densities", function()
			expect(InputManager.densityFor("desktop")).to.equal("default")
			expect(InputManager.densityFor("mobile")).to.equal("touch")
			expect(InputManager.densityFor("tablet")).to.equal("touch")
			expect(InputManager.densityFor("console")).to.equal("tv")
		end)
	end)

	describe("service", function()
		local app, cleanup
		beforeEach(function()
			app, cleanup = Harness.app()
		end)
		afterEach(function()
			cleanup()
		end)

		it("publishes input state", function()
			local input = app.state:get("input")
			expect(input.device).to.equal("desktop")
			expect(input.mode).to.equal("mouse")
			expect(input.orientation).to.equal("landscape")
			expect(input.breakpoint).to.be.ok()
		end)

		it("updates mode and device from capabilities", function()
			app.input:setMode("gamepad")
			expect(app.state:get("input.mode")).to.equal("gamepad")
			app.input:setCaps({ touch = true, viewport = Vector2.new(390, 844) })
			expect(app.state:get("input.device")).to.equal("mobile")
			expect(app.state:get("input.orientation")).to.equal("portrait")
		end)

		it("only shows the focus ring while navigating with keyboard or gamepad", function()
			local gui = Harness.mount(app)
			local button = Instance.new("TextButton")
			button.Parent = gui
			app.input:setMode("mouse")
			app.input:markFocus(button)
			expect(button:HasTag("ui-focus-visible")).to.equal(false)
			app.input:setMode("gamepad")
			app.input:markFocus(button)
			expect(button:HasTag("ui-focus-visible")).to.equal(true)
			app.input:markFocus(nil)
			expect(button:HasTag("ui-focus-visible")).to.equal(false)
		end)

		it("clears the ring when switching back to the mouse", function()
			local gui = Harness.mount(app)
			local button = Instance.new("TextButton")
			button.Parent = gui
			app.input:setMode("keyboard")
			app.input:markFocus(button)
			app.input:setMode("mouse")
			expect(button:HasTag("ui-focus-visible")).to.equal(false)
		end)

		it("keeps a stack of focus scopes", function()
			local a, b = Instance.new("Frame"), Instance.new("Frame")
			local popA = app.input:pushScope({ root = a })
			local popB = app.input:pushScope({ root = b })
			expect(app.input:topScope().root).to.equal(b)
			popB()
			expect(app.input:topScope().root).to.equal(a)
			popA()
			expect(app.input:topScope()).to.equal(nil)
		end)

		it("orders selectables in reading order for keyboard navigation", function()
			local gui = Harness.mount(app)
			local root = Instance.new("Frame")
			root.Size = UDim2.fromOffset(400, 400)
			root.Parent = gui
			local function at(name, x, y)
				local b = Instance.new("TextButton")
				b.Name = name
				b.Size = UDim2.fromOffset(50, 20)
				b.Position = UDim2.fromOffset(x, y)
				b.Parent = root
				return b
			end
			at("second", 200, 10)
			at("first", 10, 10)
			at("third", 10, 100)
			local hidden = at("hidden", 10, 200)
			hidden.Visible = false
			task.wait()
			local order = app.input:selectables(root)
			expect(#order).to.equal(3)
			expect(order[1].Name).to.equal("first")
			expect(order[2].Name).to.equal("second")
			expect(order[3].Name).to.equal("third")
		end)

		it("runs the most recent back handler first", function()
			local calls = {}
			local removeA = app.input:pushBack(function()
				table.insert(calls, "a")
			end)
			app.input:pushBack(function()
				table.insert(calls, "b")
				return true
			end)
			expect(app.input:back()).to.equal(true)
			expect(calls[1]).to.equal("b")
			removeA()
		end)
	end)
end
