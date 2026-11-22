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

		it("with trap = false, lets the D-pad move on past its edges, and B still steps out", function()
			local root, buttons = zoneOf()
			local scope = Reactive.effectScope(true)
			local zone
			scope:run(function()
				zone = Composables.useFocusZone(
					app,
					root,
					{ name = "specZoneOpen", keys = { [Enum.KeyCode.DPadUp] = "last" }, trap = false }
				)
			end)
			app.input:setMode("gamepad")
			local scopes = #app.input._scopes
			zone.enter("last")
			expect(app.input:focused()).to.equal(buttons[3])
			expect(zone.inside()).to.equal(true)
			expect(root.SelectionGroup).to.equal(false)
			expect(root.SelectionBehaviorDown).to.equal(Enum.SelectionBehavior.Escape)
			expect(#app.input._scopes).to.equal(scopes)
			expect(app.input:back()).to.equal(true)
			expect(app.input:focused()).to.equal(nil)
			expect(zone.inside()).to.equal(false)
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
end
