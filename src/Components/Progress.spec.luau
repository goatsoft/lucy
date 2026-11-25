return function()
	local Progress = require(script.Parent.Progress)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	it("computes clamped fractions", function()
		expect(Progress.fraction(50, 100)).to.equal(0.5)
		expect(Progress.fraction(150, 100)).to.equal(1)
		expect(Progress.fraction(-5, 100)).to.equal(0)
		expect(Progress.fraction(5, 0)).to.equal(0)
	end)

	it("fills a stepped bar to each marker's centre", function()
		expect(Progress.stepFraction(0, 10)).to.equal(0)
		expect(Progress.stepFraction(0.5, 10)).to.equal(0.025)
		expect(Progress.stepFraction(1, 10)).to.equal(0.05)
		expect(Progress.stepFraction(4.5, 10)).to.equal(0.4)
		expect(Progress.stepFraction(10, 10)).to.equal(0.95)
		expect(Progress.stepFraction(99, 10)).to.equal(1)
		expect(Progress.stepFraction(3, 0)).to.equal(0)
	end)

	describe("stepped", function()
		local app, cleanup, gui
		beforeEach(function()
			app, cleanup = Harness.app()
			gui = Harness.mount(app)
		end)
		afterEach(function()
			cleanup()
		end)

		it("draws a numbered marker per step, centred on its share of the width", function()
			local rail = Progress.new({ app = app, Parent = gui, steps = 4, value = 0, stepSize = 30 })
			expect(#rail.steps).to.equal(4)
			expect(rail.steps[1].Text).to.equal("1")
			expect(rail.steps[1].Position).to.equal(UDim2.fromScale(0.125, 0.5))
			expect(rail.steps[4].Position).to.equal(UDim2.fromScale(0.875, 0.5))
			expect(rail.steps[2].Size).to.equal(UDim2.fromOffset(30, 30))
		end)

		it("lights the markers the value has reached and fills to the last one", function()
			local Reactive = require(script.Parent.Parent.Core.Reactive)
			local tier = Reactive.ref(2)
			local rail = Progress.new({ app = app, Parent = gui, steps = 4, value = tier })
			expect(rail.steps[2]:HasTag("ui-progress-step-on")).to.equal(true)
			expect(rail.steps[3]:HasTag("ui-progress-step-on")).to.equal(false)
			expect(rail.indicator.Size).to.equal(UDim2.fromScale(0.375, 1))
			tier(3)
			expect(rail.steps[3]:HasTag("ui-progress-step-on")).to.equal(true)
			expect(rail.indicator.Size).to.equal(UDim2.fromScale(0.625, 1))
		end)
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

		it("follows reactive value and max", function()
			local Reactive = require(script.Parent.Parent.Core.Reactive)
			local ammo = Reactive.ref(6)
			local clip = Reactive.ref(12)
			local bar = Progress.new({ app = app, Parent = gui, value = ammo, max = clip })
			expect(bar.indicator.Size).to.equal(UDim2.fromScale(0.5, 1))
			ammo(3)
			expect(bar.indicator.Size).to.equal(UDim2.fromScale(0.25, 1))
			clip(6)
			expect(bar.indicator.Size).to.equal(UDim2.fromScale(0.5, 1))
		end)

		it("colours the bar by variant, following a getter", function()
			local Reactive = require(script.Parent.Parent.Core.Reactive)
			local health = Reactive.ref(80)
			local bar = Progress.new({
				app = app,
				Parent = gui,
				value = health,
				variant = function()
					return if health() < 25 then "destructive" else "success"
				end,
			})
			expect(bar.Instance:HasTag("ui-progress-variant-success")).to.equal(true)
			Harness.flush()
			expect(
				Harness.colorEq(
					Harness.styled(bar.indicator, "BackgroundColor3"),
					app.theme:resolve("Success")
				)
			).to.equal(true)
			health(10)
			expect(bar.Instance:HasTag("ui-progress-variant-success")).to.equal(false)
			expect(bar.Instance:HasTag("ui-progress-variant-destructive")).to.equal(true)
			Harness.flush()
			expect(
				Harness.colorEq(
					Harness.styled(bar.indicator, "BackgroundColor3"),
					app.theme:resolve("Destructive")
				)
			).to.equal(true)
		end)

		it("rejects an unknown variant", function()
			expect(function()
				Progress.new({ app = app, Parent = gui, variant = "neon" })
			end).to.throw()
		end)
	end)

	describe("circle", function()
		local app, cleanup, gui
		beforeEach(function()
			app, cleanup = Harness.app()
			gui = Harness.mount(app)
		end)
		afterEach(function()
			cleanup()
		end)

		it("computes half-ring sweep angles from a fraction", function()
			local r0, l0 = Progress.ringAngles(0)
			expect(r0).to.equal(0)
			expect(l0).to.equal(180)
			local r25, l25 = Progress.ringAngles(0.25)
			expect(r25).to.equal(90)
			expect(l25).to.equal(180)
			local r50, l50 = Progress.ringAngles(0.5)
			expect(r50).to.equal(180)
			expect(l50).to.equal(180)
			local r75, l75 = Progress.ringAngles(0.75)
			expect(r75).to.equal(180)
			expect(l75).to.equal(270)
			local r100, l100 = Progress.ringAngles(1)
			expect(r100).to.equal(180)
			expect(l100).to.equal(360)
		end)

		it("draws a circular ring that fills from value and wraps centred children", function()
			local Reactive = require(script.Parent.Parent.Core.Reactive)
			local Kbd = require(script.Parent.Kbd)
			local val = Reactive.ref(25)
			local kbd = Kbd.new({ app = app, keyboard = Enum.KeyCode.E, shape = "circle" })
			local ring = Progress.new({
				app = app,
				Parent = gui,
				shape = "circle",
				size = 36,
				value = val,
				max = 100,
				variant = "success",
				children = { kbd },
			})
			Harness.flush()
			expect(ring.Instance:HasTag("ui-progress-circle")).to.equal(true)
			expect(ring.Instance.Size).to.equal(UDim2.fromOffset(36, 36))
			expect(ring.rightGradient.Rotation).to.be.near(90, 0.01)
			expect(ring.leftHalf.Visible).to.equal(false)
			expect(kbd.Instance:IsDescendantOf(ring.Instance)).to.equal(true)
			expect(Harness.colorEq(Harness.styled(ring.rightStroke, "Color"), app.theme:resolve("Success"))).to.equal(
				true
			)

			val(75)
			expect(ring.rightGradient.Rotation).to.be.near(180, 0.01)
			expect(ring.leftHalf.Visible).to.equal(true)
			expect(ring.leftGradient.Rotation).to.be.near(270, 0.01)

			local shorthand = Progress.new({
				app = app,
				Parent = gui,
				variant = "circle",
				value = 50,
			})
			expect(shorthand:get("shape")).to.equal("circle")
			expect(shorthand.Instance:HasTag("ui-progress-circle")).to.equal(true)
		end)
	end)
end
