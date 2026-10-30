return function()
	local Actions = require(script.Parent.Actions)
	local Reactive = require(script.Parent.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local K = Enum.KeyCode

	-- Stands in for ContextActionService: records what is bound.
	local function fakeContextActions()
		local fake = { bound = {} :: { [string]: any } }
		function fake.BindActionAtPriority(_self, name, fn, touch, priority, ...)
			fake.bound[name] = { fn = fn, touch = touch, priority = priority, keys = { ... } }
		end
		function fake.UnbindAction(_self, name)
			fake.bound[name] = nil
		end
		return fake
	end

	local app, cleanup, folder, cas
	local function start(controls: string?)
		folder = Instance.new("Folder")
		folder.Name = "LucyActionsSpec"
		folder.Parent = game:GetService("ServerStorage")
		cas = fakeContextActions()
		app, cleanup = Harness.app({
			actions = { parent = folder, controls = controls or "new", contextActions = cas },
		})
	end
	afterEach(function()
		cleanup()
		folder:Destroy()
	end)

	local function context(set: string): InputContext
		return app.actions:_context(set)
	end

	local function codes(action: Instance): { string }
		local out = {}
		for _, binding in action:GetChildren() do
			if binding:IsA("InputBinding") then
				table.insert(out, binding.KeyCode.Name)
			end
		end
		table.sort(out)
		return out
	end

	describe("define", function()
		beforeEach(function()
			start()
		end)

		it("makes an InputContext per set with a Bool InputAction per action", function()
			app.actions:define("gameplay", {
				inventory = { K.I, K.ButtonL1 },
				shop = { K.B },
			})
			local ctx = context("gameplay")
			expect(ctx:IsA("InputContext")).to.equal(true)
			expect(ctx:IsDescendantOf(folder)).to.equal(true)
			expect(ctx.Priority).to.equal(Actions.priority)
			expect(ctx.Sink).to.equal(false)
			expect(ctx.Enabled).to.equal(true)
			local inventory = ctx:FindFirstChild("inventory") :: InputAction
			expect(inventory.Type).to.equal(Enum.InputActionType.Bool)
			expect(table.concat(codes(inventory), ",")).to.equal("ButtonL1,I")
			expect(table.concat(codes(ctx:FindFirstChild("shop") :: Instance), ",")).to.equal("B")
		end)

		it("takes a priority and sink, and adds actions when a set is defined again", function()
			app.actions:define("menu", { back = { K.Q } }, { priority = 1500, sink = true })
			app.actions:define("menu", { next = { K.E } })
			local ctx = context("menu")
			expect(ctx.Priority).to.equal(1500)
			expect(ctx.Sink).to.equal(true)
			expect(ctx:FindFirstChild("back")).to.be.ok()
			expect(ctx:FindFirstChild("next")).to.be.ok()
		end)

		it("rejects an action name another set already has, and stick keys", function()
			app.actions:define("gameplay", { inventory = { K.I } })
			expect(function()
				app.actions:define("menu", { inventory = { K.Tab } })
			end).to.throw()
			expect(function()
				app.actions:define("gameplay", { look = { K.Thumbstick2 } })
			end).to.throw()
		end)
	end)

	describe("on", function()
		beforeEach(function()
			start()
			app.actions:define("gameplay", { inventory = { K.I }, shop = { K.B } })
		end)

		it("runs handlers when the action is pressed until stopped", function()
			local count = 0
			local stop = app.actions:on("inventory", function()
				count += 1
			end)
			app.actions:_press("inventory")
			app.actions:_press("shop")
			expect(count).to.equal(1)
			stop()
			app.actions:_press("inventory")
			expect(count).to.equal(1)
		end)

		it("stops with the owner it was made in", function()
			local count = 0
			local scope = Reactive.effectScope(true)
			scope:run(function()
				app.actions:on("inventory", function()
					count += 1
				end)
			end)
			app.actions:_press("inventory")
			scope:stop()
			app.actions:_press("inventory")
			expect(count).to.equal(1)
		end)

		it("errors for an action that does not exist", function()
			expect(function()
				app.actions:on("nope", function() end)
			end).to.throw()
		end)
	end)

	describe("bind and keys", function()
		beforeEach(function()
			start()
			app.actions:define("gameplay", {
				inventory = { K.I, K.ButtonL1 },
				shop = { K.B, K.DPadRight },
			})
		end)

		it("gives the keys for the current input mode, tracked", function()
			local keys = Reactive.computed(function()
				return app.actions:keys("inventory")
			end)
			expect(keys()[1]).to.equal(K.I)
			expect(#keys()).to.equal(1)
			app.input:setMode("gamepad")
			expect(keys()[1]).to.equal(K.ButtonL1)
			app.input:setMode("touch")
			expect(#keys()).to.equal(0)
		end)

		it("replaces an action's keys and its bindings", function()
			local keys = Reactive.computed(function()
				return app.actions:keys("inventory")
			end)
			expect(keys()[1]).to.equal(K.I)
			app.actions:bind("inventory", { K.Tab, K.ButtonY })
			expect(keys()[1]).to.equal(K.Tab)
			expect(table.concat(codes(context("gameplay"):FindFirstChild("inventory") :: Instance), ",")).to.equal(
				"ButtonY,Tab"
			)
		end)

		it("replaces several actions in one call", function()
			app.actions:bind({ inventory = { K.Tab }, shop = { K.P } })
			expect(app.actions:keys("inventory")[1]).to.equal(K.Tab)
			expect(app.actions:keys("shop")[1]).to.equal(K.P)
		end)

		it("errors when binding an action that does not exist", function()
			expect(function()
				app.actions:bind("nope", { K.N })
			end).to.throw()
		end)
	end)

	describe("disable", function()
		beforeEach(function()
			start()
			app.actions:define("gameplay", { inventory = { K.I } })
		end)

		it("counts: a set comes back once every disable is released", function()
			local enabled = Reactive.computed(function()
				return app.actions:enabled("gameplay")
			end)
			local releaseA = app.actions:disable("gameplay")
			local releaseB = app.actions:disable("gameplay")
			expect(enabled()).to.equal(false)
			expect(context("gameplay").Enabled).to.equal(false)
			releaseA()
			releaseA()
			expect(enabled()).to.equal(false)
			releaseB()
			expect(enabled()).to.equal(true)
			expect(context("gameplay").Enabled).to.equal(true)
		end)

		it("takes several sets and gives one release", function()
			local release = app.actions:disable("gameplay", "movement")
			expect(app.actions:enabled("gameplay")).to.equal(false)
			expect(app.actions:enabled("movement")).to.equal(false)
			release()
			expect(app.actions:enabled("gameplay")).to.equal(true)
			expect(app.actions:enabled("movement")).to.equal(true)
		end)

		it("applies to a set defined after it was disabled", function()
			local release = app.actions:disable("later")
			app.actions:define("later", { wave = { K.Z } })
			expect(context("later").Enabled).to.equal(false)
			release()
			expect(context("later").Enabled).to.equal(true)
		end)
	end)

	describe("movement on the new default controls", function()
		beforeEach(function()
			start("new")
		end)

		it("holds the movement keys with a sinking context while disabled", function()
			local ctx = context("movement")
			expect(ctx.Priority).to.equal(Actions.movementPriority)
			expect(ctx.Sink).to.equal(true)
			expect(ctx.Enabled).to.equal(false)
			local release = app.actions:disable("movement")
			expect(ctx.Enabled).to.equal(true)
			expect((next(cas.bound))).to.equal(nil)
			release()
			expect(ctx.Enabled).to.equal(false)
		end)

		it("binds the stick on a direction action and the rest on a button action", function()
			local ctx = context("movement")
			local buttons = ctx:FindFirstChild("movement") :: InputAction
			local stick = ctx:FindFirstChild("movementStick") :: InputAction
			expect(buttons.Type).to.equal(Enum.InputActionType.Bool)
			expect(stick.Type).to.equal(Enum.InputActionType.Direction2D)
			expect(table.find(codes(buttons), "W")).to.be.ok()
			expect(table.find(codes(buttons), "Space")).to.be.ok()
			expect(table.concat(codes(stick), ",")).to.equal("Thumbstick1")
		end)

		it("can be given other keys", function()
			app.actions:bind("movement", { K.Z, K.Thumbstick1 })
			expect(table.concat(codes(context("movement"):FindFirstChild("movement") :: Instance), ",")).to.equal(
				"Z"
			)
		end)

		it("has no handlers", function()
			expect(function()
				app.actions:on("movement", function() end)
			end).to.throw()
		end)

		it("leaves processed keys alone", function()
			app.actions:disable("movement")
			expect(app.input:_heldByLucy(K.Down)).to.equal(false)
		end)
	end)

	describe("movement on the old default controls", function()
		beforeEach(function()
			start("old")
		end)

		it("sinks the movement keys through ContextActionService while disabled", function()
			expect((next(cas.bound))).to.equal(nil)
			local release = app.actions:disable("movement")
			local name, entry = next(cas.bound)
			expect(name).to.be.ok()
			expect(entry.priority > Enum.ContextActionPriority.High.Value).to.equal(true)
			expect(table.find(entry.keys, K.W)).to.be.ok()
			expect(table.find(entry.keys, K.Thumbstick1)).to.be.ok()
			expect(entry.fn("x", Enum.UserInputState.Begin, nil)).to.equal(Enum.ContextActionResult.Sink)
			expect(context("movement").Enabled).to.equal(false)
			release()
			expect((next(cas.bound))).to.equal(nil)
		end)

		it("tells InputManager which processed keys are its own to read", function()
			expect(app.input:_heldByLucy(K.Down)).to.equal(false)
			local release = app.actions:disable("movement")
			expect(app.input:_heldByLucy(K.Down)).to.equal(true)
			expect(app.input:_heldByLucy(K.Return)).to.equal(false)
			release()
			expect(app.input:_heldByLucy(K.Down)).to.equal(false)
		end)

		it("lets go when the app is destroyed", function()
			app.actions:disable("movement")
			local ctx = context("movement")
			cleanup()
			expect((next(cas.bound))).to.equal(nil)
			expect(ctx.Parent).to.equal(nil)
			cleanup = function() end
		end)
	end)
end
