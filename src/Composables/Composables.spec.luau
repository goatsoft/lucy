return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app()
	end)
	afterEach(function()
		cleanup()
	end)

	it("needs an owner", function()
		expect(function()
			Composables.useDensity(app)
		end).to.throw()
		expect(function()
			Composables.useBackHandler(app, true, function()
				return true
			end)
		end).to.throw()
	end)

	describe("useDensity / useMetric", function()
		it("follow the theme's density, one shared ref per app", function()
			local scope = Reactive.effectScope(true)
			local density, height
			scope:run(function()
				density = Composables.useDensity(app)
				height = Composables.useMetric(app, "ControlMd")
			end)
			expect(density()).to.equal(app.theme:getDensity())
			local before = height()
			app.theme:setDensity("touch")
			expect(density()).to.equal("touch")
			expect(height() > before).to.equal(true)
			scope:run(function()
				expect(Composables.useDensity(app)).to.equal(density)
			end)
			scope:stop()
		end)
	end)

	describe("useBackHandler", function()
		it("is on the back stack only while active", function()
			local scope = Reactive.effectScope(true)
			local open = Reactive.ref(false)
			local calls = 0
			scope:run(function()
				Composables.useBackHandler(app, open, function()
					calls += 1
					return true
				end)
			end)
			app.input:back()
			expect(calls).to.equal(0)
			open(true)
			expect(app.input:back()).to.equal(true)
			expect(calls).to.equal(1)
			open(false)
			app.input:back()
			expect(calls).to.equal(1)
			open(true)
			scope:stop()
			app.input:back()
			expect(calls).to.equal(1)
		end)
	end)

	describe("useResponsive", function()
		it("follows the input state, and passes plain values through", function()
			local scope = Reactive.effectScope(true)
			local gap, fixed
			local runs = 0
			scope:run(function()
				gap = Composables.useResponsive(app, { touch = 16, default = 8 })
				fixed = Composables.useResponsive(app, 4)
				Reactive.watchEffect(function()
					gap()
					runs += 1
				end)
			end)
			expect(gap()).to.equal(8)
			expect(fixed()).to.equal(4)
			app.input:setCaps(Harness.caps.mobile)
			app.input:setMode("touch")
			expect(gap()).to.equal(16)
			expect(runs).to.equal(2)
			scope:stop()
			expect(function()
				Composables.useResponsive(app, 4)
			end).to.throw()
		end)

		it("follows a getter as it is", function()
			local scope = Reactive.effectScope(true)
			local wide = Reactive.ref(false)
			local size
			scope:run(function()
				size = Composables.useResponsive(app, function()
					return if wide() then 300 else 100
				end)
			end)
			expect(size()).to.equal(100)
			wide(true)
			expect(size()).to.equal(300)
			scope:stop()
		end)
	end)

	describe("useFocusScope", function()
		it("pushes a focus scope only while active", function()
			local scope = Reactive.effectScope(true)
			local open = Reactive.ref(true)
			local root = Instance.new("Frame")
			local before = #app.input._scopes
			scope:run(function()
				Composables.useFocusScope(app, open, { root = root })
			end)
			expect(#app.input._scopes).to.equal(before + 1)
			open(false)
			expect(#app.input._scopes).to.equal(before)
			open(true)
			scope:stop()
			expect(#app.input._scopes).to.equal(before)
			root:Destroy()
		end)
	end)

	describe("useFocusZone", function()
		-- A zone of three buttons in a column, mounted
		local function zoneOf(): (Frame, { TextButton })
			local gui = Harness.mount(app)
			local root = Instance.new("Frame")
			root.Size = UDim2.fromOffset(100, 300)
			root.Parent = gui
			local buttons = {}
			for i = 1, 3 do
				local b = Instance.new("TextButton")
				b.Size = UDim2.fromOffset(100, 40)
				b.Position = UDim2.fromOffset(0, (i - 1) * 60)
				b.Parent = root
				table.insert(buttons, b)
			end
			Harness.flush()
			return root, buttons
		end

		it("needs a name", function()
			local scope = Reactive.effectScope(true)
			expect(function()
				scope:run(function()
					Composables.useFocusZone(app, Instance.new("Frame"), { keys = {} })
				end)
			end).to.throw()
			scope:stop()
		end)

		it("steps in with a key only while nothing is selected and it is enabled", function()
			local root, buttons = zoneOf()
			local allowed = Reactive.ref(true)
			local scope = Reactive.effectScope(true)
			scope:run(function()
				Composables.useFocusZone(app, root, {
					name = "specZoneKeys",
					keys = { [Enum.KeyCode.DPadUp] = "last", [Enum.KeyCode.DPadDown] = "first" },
					enabled = allowed,
				})
			end)
			app.input:setMode("gamepad")
			expect(app.actions:enabled("zone:specZoneKeys")).to.equal(true)
			allowed(false)
			expect(app.actions:enabled("zone:specZoneKeys")).to.equal(false)
			allowed(true)
			app.actions:_press("zone:specZoneKeys:DPadUp")
			expect(app.input:focused()).to.equal(buttons[3])
			-- Selected: the keys go back to whatever else uses them (the D-pad navigates)
			expect(app.actions:enabled("zone:specZoneKeys")).to.equal(false)
			scope:stop()
			app.input:focus(nil)
		end)

		it("keeps the D-pad inside while in, and B steps out leaving nothing selected", function()
			local root, buttons = zoneOf()
			local scope = Reactive.effectScope(true)
			local zone
			scope:run(function()
				zone = Composables.useFocusZone(
					app,
					root,
					{ name = "specZoneBack", keys = { [Enum.KeyCode.DPadUp] = "first" } }
				)
			end)
			app.input:setMode("gamepad")
			local scopes = #app.input._scopes
			zone.enter()
			expect(app.input:focused()).to.equal(buttons[1])
			expect(zone.inside()).to.equal(true)
			expect(root.SelectionGroup).to.equal(true)
			expect(root.SelectionBehaviorDown).to.equal(Enum.SelectionBehavior.Stop)
			expect(#app.input._scopes).to.equal(scopes + 1)
			expect(app.input:back()).to.equal(true)
			expect(app.input:focused()).to.equal(nil)
			expect(zone.inside()).to.equal(false)
			expect(root.SelectionGroup).to.equal(false)
			expect(#app.input._scopes).to.equal(scopes)
			scope:stop()
		end)

		it("leaves when focus goes anywhere else", function()
			local root = zoneOf()
			local other = Instance.new("TextButton")
			other.Parent = root.Parent
			local scope = Reactive.effectScope(true)
			local zone
			scope:run(function()
				zone = Composables.useFocusZone(app, root, { name = "specZoneAway", keys = {} })
			end)
			app.input:setMode("gamepad")
			zone.enter("last")
			expect(root.SelectionGroup).to.equal(true)
			app.input:focus(other)
			expect(zone.inside()).to.equal(false)
			expect(root.SelectionGroup).to.equal(false)
			scope:stop()
			app.input:focus(nil)
		end)
	end)

	describe("useSize", function()
		-- Layout lands a frame or more later (more under load): wait for it, up to a second
		local function settle(check: () -> boolean)
			local waited = 0
			while not check() and waited < 1 do
				waited += task.wait()
			end
		end
		local function near(a: number, b: number): boolean
			return math.abs(a - b) <= 0.5
		end

		it("follows the object's size in the units it is laid out in, without the scales above it", function()
			if not Harness.laysOutLive() then
				return -- sizes follow live layout only (Harness.laysOutLive)
			end
			local gui = Instance.new("ScreenGui")
			gui.Parent = Harness.guiParent()
			local scale = Instance.new("UIScale")
			scale.Scale = 2
			scale.Parent = gui
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(100, 40)
			frame.Parent = gui
			local scope = Reactive.effectScope(true)
			local size = scope:run(function()
				return Composables.useSize(frame)
			end)
			settle(function()
				return near(size().X, 100)
			end)
			expect(size().X).to.be.near(100, 0.5)
			expect(size().Y).to.be.near(40, 0.5)
			frame.Size = UDim2.fromOffset(60, 30)
			settle(function()
				return near(size().X, 60)
			end)
			expect(size().X).to.be.near(60, 0.5)
			-- A new scale changes the pixels, not the size in layout units
			scale.Scale = 0.5
			settle(function()
				return near(frame.AbsoluteSize.Y, 15)
			end)
			expect(size().Y).to.be.near(30, 0.5)
			scope:stop()
			gui:Destroy()
		end)

		it("is zero with no object, and follows a ref to one", function()
			local target = Reactive.ref(nil :: Frame?)
			local scope = Reactive.effectScope(true)
			local size = scope:run(function()
				return Composables.useSize(target)
			end)
			expect(size()).to.equal(Vector2.zero)
			if not Harness.laysOutLive() then
				scope:stop()
				return -- following the object's size needs live layout (Harness.laysOutLive)
			end
			local gui = Instance.new("ScreenGui")
			gui.Parent = Harness.guiParent()
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(80, 20)
			frame.Parent = gui
			target(frame)
			settle(function()
				return near(size().X, 80)
			end)
			expect(size().X).to.be.near(80, 0.5)
			scope:stop()
			gui:Destroy()
		end)
	end)

	describe("useHoldArrows", function()
		it("points every NextSelection at the target only while active", function()
			local button = Instance.new("TextButton")
			local active = Reactive.ref(false)
			local scope = Reactive.effectScope(true)
			scope:run(function()
				Composables.useHoldArrows(button, active)
			end)
			expect(button.NextSelectionLeft).to.equal(nil)
			active(true)
			expect(button.NextSelectionLeft).to.equal(button)
			expect(button.NextSelectionRight).to.equal(button)
			expect(button.NextSelectionUp).to.equal(button)
			expect(button.NextSelectionDown).to.equal(button)
			active(false)
			expect(button.NextSelectionDown).to.equal(nil)
			active(true)
			scope:stop()
			expect(button.NextSelectionUp).to.equal(nil)
			button:Destroy()
		end)
	end)

	describe("useUiSound", function()
		local Lucy = require(script.Parent.Parent)

		-- Records every call as "event:value".
		local function recorder()
			local calls = {}
			local function on(name: string)
				return function(_handle: any, value: any)
					table.insert(calls, if value == nil then name else `{name}:{tostring(value)}`)
				end
			end
			return calls, on
		end

		it("calls the game's function with the component that emitted", function()
			local scope = Reactive.effectScope(true)
			local got
			local button = scope:run(function()
				Composables.useUiSound(app, {
					activate = function(handle)
						got = handle
					end,
				})
				return Lucy.Button.new({ app = app })
			end)
			button:click()
			expect(got).to.equal(button)
			scope:stop()
		end)

		it("emits toggle, open and close with their value", function()
			local calls, on = recorder()
			local scope = Reactive.effectScope(true)
			local switch, checkbox, dialog = scope:run(function()
				Composables.useUiSound(app, { toggle = on("toggle"), open = on("open"), close = on("close") })
				return Lucy.Switch.new({ app = app }),
					Lucy.Checkbox.new({ app = app }),
					Lucy.Dialog.new({ app = app })
			end)
			switch:toggle()
			checkbox:toggle()
			checkbox:toggle()
			dialog:open()
			dialog:close()
			expect(table.concat(calls, " ")).to.equal("toggle:true toggle:true toggle:false open close")
			scope:stop()
		end)

		it("uses the closest map that names the event, and false silences it", function()
			local calls, on = recorder()
			local outer = Reactive.effectScope(true)
			local button, switch, quiet = outer:run(function()
				Composables.useUiSound(app, { activate = on("outer"), toggle = on("toggle") })
				local inner = Reactive.effectScope()
				local b, s = inner:run(function()
					Composables.useUiSound(app, { activate = on("inner") })
					return Lucy.Button.new({ app = app }), Lucy.Switch.new({ app = app })
				end)
				local silent = Reactive.effectScope()
				local q = silent:run(function()
					Composables.useUiSound(app, { activate = false })
					return Lucy.Button.new({ app = app })
				end)
				return b, s, q
			end)
			button:click()
			switch:toggle()
			quiet:click()
			expect(table.concat(calls, " ")).to.equal("inner toggle:true")
			outer:stop()
		end)

		it("stops when its owner stops", function()
			local calls, on = recorder()
			local sounds = Reactive.effectScope(true)
			sounds:run(function()
				Composables.useUiSound(app, { activate = on("activate") })
			end)
			local button = Lucy.Button.new({ app = app })
			button:click()
			sounds:stop()
			task.wait(0.06) -- past the double click guard
			button:click()
			expect(table.concat(calls, " ")).to.equal("activate")
			button:destroy()
		end)

		it("covers components made with no owner from a top-level scope", function()
			local calls, on = recorder()
			local sounds = Reactive.effectScope(true)
			sounds:run(function()
				Composables.useUiSound(app, { activate = on("activate") })
			end)
			local button = Lucy.Button.new({ app = app })
			button:click()
			expect(table.concat(calls, " ")).to.equal("activate")
			button:destroy()
			sounds:stop()
		end)

		it("is silenced per component with sound = false", function()
			local calls, on = recorder()
			local scope = Reactive.effectScope(true)
			local button = scope:run(function()
				Composables.useUiSound(app, { activate = on("activate") })
				return Lucy.Button.new({ app = app, sound = false })
			end)
			button:click()
			expect(#calls).to.equal(0)
			scope:stop()
		end)

		it("keeps a failing sound function from breaking the click", function()
			local clicked = false
			local scope = Reactive.effectScope(true)
			local button = scope:run(function()
				Composables.useUiSound(app, {
					activate = function()
						error("boom")
					end,
				})
				return Lucy.Button.new({
					app = app,
					onClick = function()
						clicked = true
					end,
				})
			end)
			button:click()
			expect(clicked).to.equal(true)
			scope:stop()
		end)
	end)

	describe("useAnyShown", function()
		-- Visible and child signals may be deferred: wait for each change
		local function becomes(shown: () -> boolean, value: boolean): boolean
			return Harness.waitFor(function()
				return shown() == value
			end)
		end

		it("needs an owner", function()
			expect(function()
				Composables.useAnyShown(Instance.new("Frame"))
			end).to.throw()
		end)

		it("is true while any GUI child is visible, following Visible, adds and removes", function()
			local parent = Instance.new("Frame")
			Instance.new("UIListLayout").Parent = parent -- not a GUI object: never counts
			local scope = Reactive.effectScope(true)
			local shown = scope:run(function()
				return Composables.useAnyShown(parent)
			end)
			expect(shown()).to.equal(false)
			local a = Instance.new("Frame")
			a.Visible = false
			a.Parent = parent
			task.wait()
			expect(shown()).to.equal(false)
			a.Visible = true
			expect(becomes(shown, true)).to.equal(true)
			local b = Instance.new("Frame")
			b.Parent = parent
			a.Visible = false
			task.wait()
			expect(shown()).to.equal(true)
			b:Destroy()
			expect(becomes(shown, false)).to.equal(true)
			scope:stop()
			a.Visible = true
			task.wait()
			expect(shown()).to.equal(false) -- stopped with its owner
		end)

		it("follows a target given as a ref", function()
			local target = Reactive.ref(nil :: Frame?)
			local scope = Reactive.effectScope(true)
			local shown = scope:run(function()
				return Composables.useAnyShown(target)
			end)
			expect(shown()).to.equal(false)
			local parent = Instance.new("Frame")
			Instance.new("Frame").Parent = parent
			target(parent)
			expect(shown()).to.equal(true)
			scope:stop()
		end)
	end)

	describe("useWhile", function()
		it("needs an owner", function()
			expect(function()
				Composables.useWhile(true, function() end)
			end).to.throw()
		end)

		it("runs setup each time the condition turns true and cleans up when it turns false", function()
			local on = Reactive.ref(false)
			local log = {}
			local scope = Reactive.effectScope(true)
			scope:run(function()
				Composables.useWhile(on, function()
					table.insert(log, "setup")
					return function()
						table.insert(log, "cleanup")
					end
				end)
			end)
			expect(#log).to.equal(0)
			on(true)
			on(true)
			expect(table.concat(log, ",")).to.equal("setup")
			on(false)
			on(true)
			expect(table.concat(log, ",")).to.equal("setup,cleanup,setup")
			scope:stop()
			expect(table.concat(log, ",")).to.equal("setup,cleanup,setup,cleanup")
		end)

		it("disconnects a returned connection and runs onCleanup and inner effects' cleanups", function()
			local on = Reactive.ref(true)
			local event = Instance.new("BindableEvent")
			local fired = 0
			local cleaned = 0
			local scope = Reactive.effectScope(true)
			scope:run(function()
				Composables.useWhile(on, function()
					Reactive.onCleanup(function()
						cleaned += 1
					end)
					return event.Event:Connect(function()
						fired += 1
					end)
				end)
			end)
			event:Fire()
			task.wait()
			on(false)
			event:Fire()
			task.wait()
			expect(fired).to.equal(1)
			expect(cleaned).to.equal(1)
			scope:stop()
			event:Destroy()
		end)

		it("does not rerun setup when something setup reads changes", function()
			local on = Reactive.ref(true)
			local other = Reactive.ref(1)
			local runs = 0
			local scope = Reactive.effectScope(true)
			scope:run(function()
				Composables.useWhile(on, function()
					runs += 1
					local _ = other()
				end)
			end)
			other(2)
			expect(runs).to.equal(1)
			scope:stop()
		end)

		it("does not rerun setup when the condition reads something new but stays true", function()
			local list = Reactive.ref({ "a" })
			local log = {}
			local scope = Reactive.effectScope(true)
			scope:run(function()
				Composables.useWhile(function()
					return #list() > 0
				end, function()
					table.insert(log, "setup")
					return function()
						table.insert(log, "cleanup")
					end
				end)
			end)
			list({ "a", "b" })
			list({ "b" })
			expect(table.concat(log, ",")).to.equal("setup")
			list({})
			expect(table.concat(log, ",")).to.equal("setup,cleanup")
			scope:stop()
		end)

		it("takes a getter, such as the app's modal state", function()
			local released = 0
			local scope = Reactive.effectScope(true)
			local open = Reactive.ref(false)
			scope:run(function()
				Composables.useWhile(function()
					return open()
				end, function()
					local release = app.actions:disable("movement")
					return function()
						released += 1
						release()
					end
				end)
			end)
			open(true)
			expect(app.actions:enabled("movement")).to.equal(false)
			open(false)
			expect(app.actions:enabled("movement")).to.equal(true)
			expect(released).to.equal(1)
			scope:stop()
		end)
	end)

	describe("useCountdown", function()
		it("needs an owner", function()
			expect(function()
				Composables.useCountdown(0)
			end).to.throw()
		end)

		it("counts whole seconds down to zero, then is done", function()
			local scope = Reactive.effectScope(true)
			local countdown
			local start = os.clock()
			scope:run(function()
				countdown = Composables.useCountdown(start + 1.1, { now = os.clock })
			end)
			expect(countdown.remaining()).to.equal(2)
			expect(countdown.done()).to.equal(false)
			task.wait(0.3)
			expect(countdown.remaining()).to.equal(1)
			task.wait(1)
			expect(countdown.remaining()).to.equal(0)
			expect(countdown.done()).to.equal(true)
			scope:stop()
		end)

		it("follows a changed end time and is not done without one", function()
			local scope = Reactive.effectScope(true)
			local endsAt = Reactive.ref(nil :: number?)
			local countdown
			scope:run(function()
				countdown = Composables.useCountdown(endsAt, { now = os.clock })
			end)
			expect(countdown.remaining()).to.equal(0)
			expect(countdown.done()).to.equal(false)
			endsAt(os.clock() + 9.5)
			expect(countdown.remaining()).to.equal(10)
			endsAt(os.clock() - 1)
			expect(countdown.remaining()).to.equal(0)
			expect(countdown.done()).to.equal(true)
			scope:stop()
		end)
	end)

	describe("useDrag", function()
		-- Fake input: InputBegan on the target and UserInputService's InputChanged and InputEnded.
		-- Inputs are plain tables with the fields useDrag reads.
		local function fakeInput()
			local began, changed, ended =
				Instance.new("BindableEvent"), Instance.new("BindableEvent"), Instance.new("BindableEvent")
			return {
				began = began.Event,
				input = { InputChanged = changed.Event, InputEnded = ended.Event },
				press = function(x: number, y: number)
					began:Fire({
						UserInputType = Enum.UserInputType.MouseButton1,
						Position = Vector3.new(x, y, 0),
					})
				end,
				move = function(x: number, y: number)
					changed:Fire({
						UserInputType = Enum.UserInputType.MouseMovement,
						Position = Vector3.new(x, y, 0),
					})
				end,
				release = function()
					ended:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero })
				end,
				destroy = function()
					began:Destroy()
					changed:Destroy()
					ended:Destroy()
				end,
			}
		end

		it("needs an owner", function()
			expect(function()
				Composables.useDrag(Instance.new("Frame"))
			end).to.throw()
		end)

		it("follows a press, the moves and the release", function()
			local fake = fakeInput()
			local log = {}
			local scope = Reactive.effectScope(true)
			local drag
			scope:run(function()
				drag = Composables.useDrag(Instance.new("Frame"), {
					began = fake.began,
					input = fake.input,
					onStart = function(point)
						table.insert(log, `start {point.X},{point.Y}`)
					end,
					onMove = function(delta, point)
						table.insert(log, `move {delta.X},{delta.Y} at {point.X},{point.Y}`)
					end,
					onEnd = function(delta)
						table.insert(log, `end {delta.X},{delta.Y}`)
					end,
				})
			end)
			expect(drag.dragging()).to.equal(false)
			fake.press(10, 20)
			task.wait()
			expect(drag.dragging()).to.equal(true)
			fake.move(15, 18)
			task.wait()
			expect(drag.delta()).to.equal(Vector2.new(5, -2))
			fake.release()
			task.wait()
			expect(drag.dragging()).to.equal(false)
			expect(drag.delta()).to.equal(Vector2.zero)
			expect(table.concat(log, "; ")).to.equal("start 10,20; move 5,-2 at 15,18; end 5,-2")
			scope:stop()
			fake.destroy()
		end)

		it("ignores presses while disabled, and ends a drag when disabled", function()
			local fake = fakeInput()
			local disabled = Reactive.ref(true)
			local scope = Reactive.effectScope(true)
			local drag
			scope:run(function()
				drag = Composables.useDrag(Instance.new("Frame"), {
					began = fake.began,
					input = fake.input,
					disabled = disabled,
				})
			end)
			fake.press(0, 0)
			task.wait()
			expect(drag.dragging()).to.equal(false)
			disabled(false)
			fake.move(4, 4)
			task.wait()
			expect(drag.dragging()).to.equal(false)
			fake.press(1, 1)
			task.wait()
			expect(drag.dragging()).to.equal(true)
			-- turning it off mid drag ends the drag
			disabled(true)
			expect(drag.dragging()).to.equal(false)
			scope:stop()
			fake.destroy()
		end)

		it("cancel() ends a drag, and stopping the owner disconnects it", function()
			local fake = fakeInput()
			local ends = 0
			local moves = 0
			local scope = Reactive.effectScope(true)
			local drag
			scope:run(function()
				drag = Composables.useDrag(Instance.new("Frame"), {
					began = fake.began,
					input = fake.input,
					onMove = function()
						moves += 1
					end,
					onEnd = function()
						ends += 1
					end,
				})
			end)
			fake.press(0, 0)
			task.wait()
			drag.cancel()
			expect(drag.dragging()).to.equal(false)
			expect(ends).to.equal(1)
			fake.move(3, 3)
			task.wait()
			expect(moves).to.equal(0)
			fake.press(0, 0)
			task.wait()
			scope:stop()
			fake.move(3, 3)
			fake.press(0, 0)
			task.wait()
			expect(moves).to.equal(0)
			expect(ends).to.equal(2)
			fake.destroy()
		end)
	end)

	describe("useReveal / useCount", function()
		local Animate = require(script.Parent.Parent.Core.Animate)

		beforeEach(function()
			Animate.manual = true
		end)
		afterEach(function()
			Animate.manual = false
		end)

		local function run(seconds: number)
			for _ = 1, math.round(seconds * 60) do
				Animate.step(1 / 60)
			end
		end

		local function owned(fn: () -> any): (any, any)
			local scope = Reactive.effectScope(true)
			local result
			scope:run(function()
				result = fn()
			end)
			return result, scope
		end

		it("useReveal shows a text a character at a time, again when it changes", function()
			local line = Reactive.ref("Hello there")
			local typed, scope = owned(function()
				return Composables.useReveal(line, { rate = 10 })
			end)
			expect(typed.visible()).to.equal(0)
			expect(typed.revealing()).to.equal(true)
			run(0.5)
			expect(typed.visible()).to.equal(5)
			local done = 0
			typed.done:Connect(function()
				done += 1
			end)
			run(1)
			expect(typed.visible()).to.equal(-1) -- all of it
			expect(typed.revealing()).to.equal(false)
			expect(done).to.equal(1)
			line("Again")
			expect(typed.visible()).to.equal(0)
			typed.skip()
			expect(typed.visible()).to.equal(-1)
			expect(done).to.equal(2)
			scope:stop()
		end)

		it("useReveal counts rich text by what a reader sees", function()
			local typed, scope = owned(function()
				return Composables.useReveal("<b>Hey</b> &amp; you", { rate = 10, rich = true })
			end)
			run(0.8)
			expect(typed.visible()).to.equal(8)
			run(0.2)
			expect(typed.visible()).to.equal(-1) -- "Hey & you" is 9
			scope:stop()
		end)

		it("useCount eases a number to its value, on from where it is when it changes", function()
			local xp = Reactive.ref(100)
			local count, scope = owned(function()
				return Composables.useCount(xp, { seconds = 1 })
			end)
			expect(count.value()).to.equal(0)
			expect(count.counting()).to.equal(true)
			run(0.5)
			expect(count.value() > 50 and count.value() < 100).to.equal(true) -- eases out: past half way
			run(0.6)
			expect(count.value()).to.equal(100)
			expect(count.counting()).to.equal(false)
			xp(250)
			run(0.3)
			expect(count.value() > 100 and count.value() < 250).to.equal(true)
			local done = 0
			count.done:Connect(function()
				done += 1
			end)
			count.skip()
			expect(count.value()).to.equal(250)
			expect(done).to.equal(1)
			scope:stop()
		end)

		it("useCount starts from `from`, and needs an owner", function()
			local count, scope = owned(function()
				return Composables.useCount(50, { seconds = 1, from = 40 })
			end)
			expect(count.value()).to.equal(40)
			run(1.1)
			expect(count.value()).to.equal(50)
			scope:stop()
			expect(function()
				Composables.useCount(1)
			end).to.throw()
			expect(function()
				Composables.useReveal("x")
			end).to.throw()
		end)
	end)
	describe("useRequest", function()
		-- A server whose calls wait until the spec answers them, in any order.
		local function fakeServer()
			local server =
				{ calls = {} :: { { name: string, args: { n: number, [number]: any }, thread: thread } } }
			function server.call(_self: any, name: string, ...: any): any
				local call = { name = name, args = table.pack(...), thread = coroutine.running() }
				table.insert(server.calls, call)
				local ok, value = coroutine.yield()
				if not ok then
					error(value, 0)
				end
				return value
			end
			-- Answers call `index` (the oldest still waiting by default)
			function server.answer(index: number, value: any)
				local call = server.calls[index]
				task.spawn(call.thread, true, value)
			end
			function server.fail(index: number, message: string)
				task.spawn(server.calls[index].thread, false, message)
			end
			return server
		end

		local server, fakeApp
		beforeEach(function()
			server = fakeServer()
			fakeApp = { server = server }
		end)

		it("needs an owner", function()
			expect(function()
				Composables.useRequest(fakeApp, "boards.get")
			end).to.throw()
		end)

		it("calls the server, loading until the answer comes", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", function()
					return "combo", "week"
				end)
			end)
			expect(#server.calls).to.equal(1)
			expect(server.calls[1].name).to.equal("boards.get")
			expect(server.calls[1].args[1]).to.equal("combo")
			expect(server.calls[1].args[2]).to.equal("week")
			expect(request.loading()).to.equal(true)
			expect(request.data()).to.equal(nil)
			server.answer(1, { rows = { 1, 2 } })
			expect(request.loading()).to.equal(false)
			expect(#request.data().rows).to.equal(2)
			expect(request.error()).to.equal(nil)
			scope:stop()
		end)

		it("calls again when an argument changes, and drops a late answer to the old one", function()
			local scope = Reactive.effectScope(true)
			local board = Reactive.ref("combo")
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", function()
					return board()
				end)
			end)
			server.answer(1, "combo board")
			expect(request.data()).to.equal("combo board")
			board("coins")
			expect(#server.calls).to.equal(2)
			expect(server.calls[2].args[1]).to.equal("coins")
			-- the old answer goes as soon as the question changes
			expect(request.data()).to.equal(nil)
			expect(request.loading()).to.equal(true)
			board("hype")
			server.answer(3, "hype board")
			server.answer(2, "coins board") -- late: the player has moved on
			expect(request.data()).to.equal("hype board")
			expect(request.loading()).to.equal(false)
			scope:stop()
		end)

		it("keeps the last answer while the next one loads, with keep", function()
			local scope = Reactive.effectScope(true)
			local board = Reactive.ref("combo")
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", function()
					return board()
				end, { keep = true })
			end)
			server.answer(1, "combo board")
			board("coins")
			expect(request.data()).to.equal("combo board")
			expect(request.loading()).to.equal(true)
			server.answer(2, "coins board")
			expect(request.data()).to.equal("coins board")
			scope:stop()
		end)

		it("reports an error and keeps what it had", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get")
			end)
			server.answer(1, "board")
			request.refresh()
			expect(request.loading()).to.equal(true)
			server.fail(2, "too many requests")
			expect(request.loading()).to.equal(false)
			expect(request.error()).to.equal("too many requests")
			expect(request.data()).to.equal("board")
			request.refresh()
			server.answer(3, "board again")
			expect(request.error()).to.equal(nil)
			scope:stop()
		end)

		it("refreshes on demand, keeping the answer it has meanwhile", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get")
			end)
			server.answer(1, "board")
			request.refresh()
			expect(#server.calls).to.equal(2)
			expect(request.data()).to.equal("board")
			server.answer(2, "newer board")
			expect(request.data()).to.equal("newer board")
			scope:stop()
		end)

		it("waits while enabled is false", function()
			local scope = Reactive.effectScope(true)
			local open = Reactive.ref(false)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", nil, { enabled = open })
			end)
			expect(#server.calls).to.equal(0)
			expect(request.loading()).to.equal(false)
			request.refresh()
			expect(#server.calls).to.equal(0)
			open(true)
			expect(#server.calls).to.equal(1)
			scope:stop()
		end)

		it("asks again every few seconds, with every", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", nil, { every = 0.05 })
			end)
			server.answer(1, "board")
			task.wait(0.08)
			expect(#server.calls).to.equal(2)
			expect(request.loading()).to.equal(true)
			expect(request.data()).to.equal("board")
			server.answer(2, "board 2")
			scope:stop()
			task.wait(0.1)
			expect(#server.calls).to.equal(2)
		end)

		it("drops an answer that comes after its owner stopped", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get")
			end)
			scope:stop()
			server.answer(1, "board")
			expect(request.data()).to.equal(nil)
		end)
	end)
end
