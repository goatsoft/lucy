return function()
	local RadioGroup = require(script.Parent.RadioGroup)
	local Composables = require(script.Parent.Parent.Composables)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local OPTIONS = { { value = "easy", label = "Easy" }, { value = "hard", label = "Hard" }, "Expert" }

	it("makes a row per option with a circle and a label", function()
		local group = RadioGroup.new({ app = app, Parent = gui, items = OPTIONS })
		expect(#group.items).to.equal(3)
		local row = group.items[1]
		expect(row.root:IsA("TextButton")).to.equal(true)
		expect(row.label.Text).to.equal("Easy")
		expect(group.items[3].label.Text).to.equal("Expert")
		expect(row.circle:HasTag("ui-radio")).to.equal(true)
		expect(row.dot.Visible).to.equal(false)
	end)

	it("picks one option and never clears it", function()
		local group = RadioGroup.new({ app = app, Parent = gui, items = OPTIONS })
		expect(group:get("value")).to.equal(false)
		group:select("hard")
		expect(group:get("value")).to.equal("hard")
		expect(group.items[2].dot.Visible).to.equal(true)
		expect(group.items[2].circle:HasTag("ui-selected")).to.equal(true)
		group:select("hard")
		expect(group:get("value")).to.equal("hard")
		group:select("Expert")
		expect(group.items[2].dot.Visible).to.equal(false)
		expect(group.items[3].dot.Visible).to.equal(true)
	end)

	it("keeps value in step with a ref, both ways", function()
		local level = Reactive.ref("easy")
		local group = RadioGroup.new({ app = app, Parent = gui, items = OPTIONS, value = level })
		expect(group.items[1].dot.Visible).to.equal(true)
		group:select("hard")
		expect(level()).to.equal("hard")
		level("Expert")
		expect(group.items[3].dot.Visible).to.equal(true)
	end)

	it("reports changes and emits select from the player path only", function()
		local seen, calls = {}, {}
		local scope = Reactive.effectScope(true)
		local group = scope:run(function()
			Composables.useUiSound(app, {
				select = function(_, value)
					table.insert(calls, value)
				end,
			})
			return RadioGroup.new({
				app = app,
				Parent = gui,
				items = OPTIONS,
				onValueChange = function(value)
					table.insert(seen, value)
				end,
			})
		end)
		group:select("easy")
		group:select("easy")
		group:set("value", "hard")
		expect(table.concat(seen, ",")).to.equal("easy,hard")
		expect(table.concat(calls, ",")).to.equal("easy")
		scope:stop()
	end)

	it("ignores the player while the group or an option is disabled", function()
		local group = RadioGroup.new({
			app = app,
			Parent = gui,
			items = { "A", { value = "B", disabled = true } },
		})
		group:select("B")
		expect(group:get("value")).to.equal(false)
		expect(group.items[2].root.Interactable).to.equal(false)
		expect(group.items[2].label:HasTag("ui-disabled")).to.equal(true)
		group:set("disabled", true)
		group:select("A")
		expect(group:get("value")).to.equal(false)
	end)

	it("stacks options in a column by default, or a row", function()
		local column = RadioGroup.new({ app = app, Parent = gui, items = OPTIONS })
		expect(column.Instance:FindFirstChildOfClass("UIListLayout").FillDirection).to.equal(
			Enum.FillDirection.Vertical
		)
		local row = RadioGroup.new({ app = app, Parent = gui, items = OPTIONS, orientation = "horizontal" })
		expect(row.Instance:FindFirstChildOfClass("UIListLayout").FillDirection).to.equal(
			Enum.FillDirection.Horizontal
		)
	end)

	it("grows the circle with density", function()
		local group = RadioGroup.new({ app = app, Parent = gui, items = OPTIONS })
		expect(group.items[1].circle.Size.X.Offset).to.equal(16)
		app.input:setCaps(Harness.caps.mobile)
		expect(group.items[1].circle.Size.X.Offset).to.equal(20)
	end)

	it("fills the dot with primary", function()
		local group = RadioGroup.new({ app = app, Parent = gui, items = OPTIONS, value = "easy" })
		Harness.flush()
		local dot = group.items[1].dot
		expect(Harness.colorEq(Harness.styled(dot, "BackgroundColor3"), app.theme:resolve("Primary"))).to.equal(
			true
		)
	end)

	it("rings the circle, not the whole row, when focused with a pad or keys", function()
		local group = RadioGroup.new({ app = app, Parent = gui, items = OPTIONS })
		local row = group.items[1].root
		local part = group.items[1].circle
		local ring = part:FindFirstChild("Ring")
		expect(ring ~= nil).to.equal(true)
		local stroke = ring:FindFirstChildWhichIsA("UIStroke")
		expect(ring.Size.X.Offset > 0).to.equal(true)
		Harness.flush()
		expect(Harness.styled(stroke, "Transparency")).to.be.near(1, 0.001)
		app.input:setMode("gamepad")
		app.input:focus(row)
		expect(row:HasTag("ui-focus-visible")).to.equal(true)
		Harness.flush()
		expect(Harness.styled(stroke, "Transparency")).to.be.near(0, 0.001)
		expect(Harness.colorEq(Harness.styled(stroke, "Color"), app.theme:resolve("Ring"))).to.equal(true)
		expect(Harness.styled(stroke, "Thickness")).to.be.near(app.theme:resolve("FocusRing"), 0.001)
		local rowStroke = row:FindFirstChildWhichIsA("UIStroke")
		if rowStroke then
			expect(Harness.styled(rowStroke, "Transparency")).to.be.near(1, 0.001)
		end
	end)
end
