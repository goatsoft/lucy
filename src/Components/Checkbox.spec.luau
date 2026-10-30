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
		expect(Harness.colorEq(Harness.styled(checkbox.box, "BackgroundColor3"), app.theme:resolve("Primary"))).to.equal(true)
	end)
end
