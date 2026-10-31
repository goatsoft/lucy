return function()
	local Checkbox = require(script.Parent.Checkbox)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("keeps checked in step with a ref, both ways", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local muted = Reactive.ref(false)
		local seen = {}
		local checkbox = Checkbox.new({
			app = app,
			Parent = gui,
			checked = muted,
			label = function()
				return if muted() then "Muted" else "Mute"
			end,
			onCheckedChange = function(checked)
				table.insert(seen, checked)
			end,
		})
		checkbox:toggle()
		expect(muted()).to.equal(true)
		expect(checkbox.label.Text).to.equal("Muted")
		muted(false)
		expect(checkbox.check.Visible).to.equal(false)
		expect(#seen).to.equal(2)
		expect(seen[2]).to.equal(false)
	end)

	it("follows a reactive disabled", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local locked = Reactive.ref(true)
		local checkbox = Checkbox.new({ app = app, Parent = gui, disabled = locked })
		checkbox:toggle()
		expect(checkbox:get("checked")).to.equal(false)
		locked(false)
		checkbox:toggle()
		expect(checkbox:get("checked")).to.equal(true)
	end)

	it("toggles and reports changes", function()
		local seen = {}
		local checkbox = Checkbox.new({
			app = app,
			id = "mute",
			Parent = gui,
			label = "Mute",
			onCheckedChange = function(checked)
				table.insert(seen, checked)
			end,
		})
		expect(checkbox.check.Visible).to.equal(false)
		checkbox:toggle()
		expect(app.state:get("ui.mute.checked")).to.equal(true)
		expect(checkbox.check.Visible).to.equal(true)
		expect(checkbox.box:HasTag("ui-checked")).to.equal(true)
		app.state:set("ui.mute.checked", false)
		expect(#seen).to.equal(2)
		expect(seen[2]).to.equal(false)
	end)

	it("ignores toggles while disabled", function()
		local checkbox = Checkbox.new({ app = app, Parent = gui, disabled = true })
		checkbox:toggle()
		expect(checkbox:get("checked")).to.equal(false)
		expect(checkbox.Instance.Interactable).to.equal(false)
	end)

	it("hides the label when empty", function()
		local checkbox = Checkbox.new({ app = app, Parent = gui })
		expect(checkbox.label.Visible).to.equal(false)
	end)

	it("grows the box and hit area with density", function()
		local checkbox = Checkbox.new({ app = app, Parent = gui, label = "x" })
		expect(checkbox.box.Size.X.Offset).to.equal(16)
		app.input:setCaps(Harness.caps.mobile)
		expect(checkbox.box.Size.X.Offset).to.equal(20)
		expect(checkbox.Instance.Size.Y.Offset >= 40).to.equal(true)
	end)

	it("fills with primary when checked", function()
		local checkbox = Checkbox.new({ app = app, Parent = gui, checked = true })
		Harness.flush()
		expect(
			Harness.colorEq(Harness.styled(checkbox.box, "BackgroundColor3"), app.theme:resolve("Primary"))
		).to.equal(true)
	end)

	it("rings the box, not the whole row, when focused with a pad or keys", function()
		local checkbox = Checkbox.new({ app = app, Parent = gui, label = "Mute" })
		local row = checkbox.Instance
		local part = checkbox.box
		local ring = part:FindFirstChild("Ring")
		expect(ring ~= nil).to.equal(true)
		local stroke = ring:FindFirstChildWhichIsA("UIStroke")
		expect(ring.Size).to.equal(UDim2.fromScale(1, 1))
		Harness.flush()
		expect(Harness.styled(stroke, "Transparency")).to.be.near(1, 0.001)
		app.input:setMode("gamepad")
		app.input:focus(row)
		expect(row:HasTag("ui-focus-visible")).to.equal(true)
		Harness.flush()
		expect(Harness.styled(stroke, "Transparency")).to.be.near(0, 0.001)
		expect(Harness.colorEq(Harness.styled(stroke, "Color"), app.theme:resolve("Ring"))).to.equal(true)
		expect(Harness.styled(stroke, "Thickness")).to.be.near(app.theme:resolve("FocusRing"), 0.001)
		expect(Harness.styled(stroke, "BorderStrokePosition")).to.equal(Enum.BorderStrokePosition.Inner)
		local rowStroke = row:FindFirstChildWhichIsA("UIStroke")
		if rowStroke then
			expect(Harness.styled(rowStroke, "Transparency")).to.be.near(1, 0.001)
		end
	end)
end
