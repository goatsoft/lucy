return function()
	local Progress = require(script.Parent.Progress)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	it("computes clamped fractions", function()
		expect(Progress.fraction(50, 100)).to.equal(0.5)
		expect(Progress.fraction(150, 100)).to.equal(1)
		expect(Progress.fraction(-5, 100)).to.equal(0)
		expect(Progress.fraction(5, 0)).to.equal(0)
	end)

	describe("component", function()
		local app, cleanup, gui
		beforeEach(function()
			app, cleanup = Harness.app()
			gui = Harness.mount(app)
		end)
		afterEach(function()
			cleanup()
		end)

		it("sizes the indicator from value and max", function()
			local bar = Progress.new({ app = app, id = "reload", Parent = gui, value = 25 })
			expect(bar.indicator.Size).to.equal(UDim2.fromScale(0.25, 1))
			app.state:merge("ui.reload", { value = 3, max = 4 })
			expect(bar.indicator.Size).to.equal(UDim2.fromScale(0.75, 1))
		end)
	end)
end
