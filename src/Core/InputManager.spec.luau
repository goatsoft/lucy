return function()
	describe("default focus inside a component", function()
		local Harness = require(script.Parent.Parent.Testing.Harness)
		it("falls back to the first selectable under a target that can't take focus", function()
			local app, cleanup = Harness.app()
			local gui = Harness.mount(app)
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(100, 100)
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(50, 20)
			button.Parent = frame
			frame.Parent = gui
			local pop = app.input:pushScope({
				root = gui,
				defaultFocus = function()
					return frame
				end,
			})
			app.input:focusDefault()
			local focused = app.input:focused()
			pop()
			cleanup()
			expect(focused).to.equal(button)
		end)
	end)

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

		it("returns focus to returnFocus when a scope pops", function()
			local gui = Harness.mount(app)
			local opener = Instance.new("TextButton")
			opener.Position = UDim2.fromOffset(0, 300)
			opener.Parent = gui
			local panel = Instance.new("Frame")
			panel.Parent = gui
			local inside = Instance.new("TextButton")
			inside.Parent = panel
			app.input:setMode("gamepad")
			app.input:focus(opener)
			local pop = app.input:pushScope({ root = panel, defaultFocus = inside, returnFocus = opener })
			expect(app.input:focused()).to.equal(inside)
			pop()
			expect(app.input:focused()).to.equal(opener)
		end)

		it("returns focus to what had it when the scope was pushed", function()
			local gui = Harness.mount(app)
			local opener = Instance.new("TextButton")
			opener.Position = UDim2.fromOffset(0, 300)
			opener.Parent = gui
			local panel = Instance.new("Frame")
			panel.Parent = gui
			local inside = Instance.new("TextButton")
			inside.Parent = panel
			app.input:setMode("gamepad")
			app.input:focus(opener)
			local pop = app.input:pushScope({ root = panel, defaultFocus = inside })
			pop()
			expect(app.input:focused()).to.equal(opener)
		end)

		it("takes returnFocus as a function and skips it when hidden", function()
			local gui = Harness.mount(app)
			local opener = Instance.new("TextButton")
			opener.Parent = gui
			local panel = Instance.new("Frame")
			panel.Parent = gui
			local inside = Instance.new("TextButton")
			inside.Parent = panel
			app.input:setMode("gamepad")
			local pop = app.input:pushScope({
				root = panel,
				defaultFocus = inside,
				returnFocus = function()
					return opener
				end,
			})
			opener.Visible = false
			panel.Visible = false
			pop()
			expect(app.input:focused()).never.to.equal(opener)
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

	describe("nudge", function()
		it("is not taken with nothing focused, and release is then harmless", function()
			local app, cleanup = Harness.app()
			expect(app.input:nudge(1, 0)).to.equal(false)
			app.input:release()
			cleanup()
		end)

		it("is not taken by a focused object with no nudge method", function()
			local app, cleanup = Harness.app()
			local gui = Harness.mount(app)
			local frame = Instance.new("TextButton")
			frame.Parent = gui
			app.input:focus(frame)
			expect(app.input:nudge(0, 1)).to.equal(false)
			cleanup()
		end)
	end)

	describe("activate", function()
		local Stack = require(script.Parent.Parent.Components.Stack)

		it("asks the components around the focus to press it, the innermost first", function()
			local app, cleanup = Harness.app()
			local gui = Harness.mount(app)
			local seen = {}
			local outer = Stack.new({ app = app, Parent = gui })
			local inner = Stack.new({ app = app, Parent = outer.Instance })
			local button = Instance.new("TextButton")
			button.Parent = inner.Instance
			outer.press = function(_, object)
				table.insert(seen, "outer:" .. object.Name)
				return true
			end
			inner.press = function(_, object)
				table.insert(seen, "inner:" .. object.Name)
				return object.Name == "Mine"
			end
			app.input:focus(button)
			app.input:activate()
			button.Name = "Mine"
			app.input:activate()
			expect(table.concat(seen, ",")).to.equal("inner:TextButton,outer:TextButton,inner:Mine")
			cleanup()
		end)

		it("does nothing with nothing focused", function()
			local app, cleanup = Harness.app()
			app.input:activate()
			cleanup()
		end)
	end)
end
