return function()
	local Switch = require(script.Parent.Switch)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("places the thumb by checked state", function()
		local switch = Switch.new({ app = app, Parent = gui })
		expect(switch.thumb.Position.X.Offset).to.equal(2)
		local on = Switch.new({ app = app, Parent = gui, checked = true })
		expect(on.thumb.Position.X.Offset).to.equal(36 - 16 - 2)
	end)

	it("toggles through state and reports changes", function()
		local seen
		local switch = Switch.new({
			app = app,
			id = "music",
			Parent = gui,
			onCheckedChange = function(checked)
				seen = checked
			end,
		})
		switch:toggle()
		expect(app.state:get("ui.music.checked")).to.equal(true)
		expect(switch.track:HasTag("ui-checked")).to.equal(true)
		expect(seen).to.equal(true)
	end)

	it("ignores toggles while disabled", function()
		local switch = Switch.new({ app = app, Parent = gui, disabled = true })
		switch:toggle()
		expect(switch:get("checked")).to.equal(false)
	end)

	it("resizes with density", function()
		local switch = Switch.new({ app = app, Parent = gui })
		expect(switch.track.Size).to.equal(UDim2.fromOffset(36, 20))
		app.input:setCaps(Harness.caps.console)
		expect(switch.track.Size).to.equal(UDim2.fromOffset(52, 28))
		expect(switch.thumb.Size).to.equal(UDim2.fromOffset(24, 24))
	end)

	it("uses the primary colour when on", function()
		local switch = Switch.new({ app = app, Parent = gui, checked = true })
		Harness.flush()
		expect(Harness.colorEq(Harness.styled(switch.track, "BackgroundColor3"), app.theme:resolve("Primary"))).to.equal(true)
	end)
end
