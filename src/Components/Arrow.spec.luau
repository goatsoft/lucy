return function()
	local Arrow = require(script.Parent.Arrow)
	local Preferences = require(script.Parent.Parent.Core.Preferences)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		Preferences.setReducedMotion(nil)
		cleanup()
	end)

	local function near(a: number, b: number, within: number?): boolean
		return math.abs(a - b) <= (within or 0.01)
	end

	-- Samples a function over `seconds` of frames, returning the lowest and highest value.
	local function range(seconds: number, read: () -> number): (number, number)
		local low, high = math.huge, -math.huge
		local finish = os.clock() + seconds
		while os.clock() < finish do
			local value = read()
			low, high = math.min(low, value), math.max(high, value)
			task.wait()
		end
		return low, high
	end

	local function offset(arrow): number
		local p = arrow.body.Position
		return math.abs(p.X.Offset) + math.abs(p.Y.Offset)
	end

	describe("shape", function()
		it("draws an arrow by default, or a chevron or a triangle", function()
			local arrow = Arrow.new({ app = app, Parent = gui })
			expect(arrow.parts.arrow.Visible).to.equal(true)
			expect(arrow.parts.chevron.Visible).to.equal(false)
			expect(arrow.parts.triangle.Visible).to.equal(false)
			arrow:set("variant", "chevron")
			expect(arrow.parts.arrow.Visible).to.equal(false)
			expect(arrow.parts.chevron.Visible).to.equal(true)
			arrow:set("variant", "triangle")
			expect(arrow.parts.triangle.Visible).to.equal(true)
			expect(Harness.findChildOfClass(arrow.parts.triangle, "Frame")).to.be.ok()
		end)

		it("rejects an unknown variant, motion or direction", function()
			expect(function()
				Arrow.new({ app = app, variant = "star" })
			end).to.throw()
			expect(function()
				Arrow.new({ app = app, motion = "spin" })
			end).to.throw()
			expect(function()
				Arrow.new({ app = app, direction = "sideways" })
			end).to.throw()
		end)

		it("puts its tip at its position, whichever way it points", function()
			local arrow = Arrow.new({ app = app, Parent = gui })
			local expected = {
				down = { Vector2.new(0.5, 1), 0 },
				up = { Vector2.new(0.5, 0), 180 },
				left = { Vector2.new(0, 0.5), 90 },
				right = { Vector2.new(1, 0.5), -90 },
			}
			for direction, want in expected do
				arrow:set("direction", direction)
				expect(arrow.Instance.AnchorPoint).to.equal(want[1])
				expect(arrow.shape.Rotation).to.equal(want[2])
			end
		end)

		it("is sized by name or in pixels", function()
			local arrow = Arrow.new({ app = app, Parent = gui, size = "sm" })
			expect(arrow.Instance.Size).to.equal(UDim2.fromOffset(Arrow.sizes.sm, Arrow.sizes.sm))
			arrow:set("size", 50)
			expect(arrow.Instance.Size).to.equal(UDim2.fromOffset(50, 50))
		end)

		it("takes its colour from a token or a Color3", function()
			local arrow = Arrow.new({ app = app, Parent = gui, color = "Destructive" })
			local shaft = arrow.parts.arrow:FindFirstChild("Shaft") :: Frame
			expect(Harness.colorEq(shaft.BackgroundColor3, app.theme:resolve("Destructive"))).to.equal(true)
			arrow:set("color", Color3.new(0, 1, 0))
			expect(Harness.colorEq(shaft.BackgroundColor3, Color3.new(0, 1, 0))).to.equal(true)
		end)

		it("draws an icon in place of the shape", function()
			local arrow = Arrow.new({ app = app, Parent = gui, icon = "lucy:chevron-down" })
			expect(arrow.icon.Instance.Visible).to.equal(true)
			expect(arrow.parts.arrow.Visible).to.equal(false)
			arrow:set("icon", nil)
			expect(arrow.icon.Instance.Visible).to.equal(false)
			expect(arrow.parts.arrow.Visible).to.equal(true)
		end)
	end)

	-- Motion runs on the frame clock: these need Play.
	describe("motion", function()
		it("grows in, on a curve that overshoots and settles at 1", function()
			local peak = 0
			for i = 0, 100 do
				peak = math.max(peak, Arrow.ease(i / 100))
			end
			expect(peak > 1.05).to.equal(true)
			expect(near(Arrow.ease(0), 0)).to.equal(true)
			expect(near(Arrow.ease(1), 1)).to.equal(true)

			local arrow = Arrow.new({ app = app, Parent = gui, motion = "none" })
			task.wait()
			expect(arrow.scale.Scale < 1).to.equal(true)
			task.wait(Arrow.timing.grow + 0.1)
			expect(near(arrow.scale.Scale, 1)).to.equal(true)
		end)

		it("bounces toward its tip", function()
			local arrow = Arrow.new({ app = app, Parent = gui, motion = "bounce", size = 40 })
			task.wait(Arrow.timing.grow)
			local low, high = range(Arrow.timing.period * 1.5, function()
				return offset(arrow)
			end)
			expect(low < 1).to.equal(true)
			expect(high > 4).to.equal(true)
		end)

		it("pulses without moving", function()
			local arrow = Arrow.new({ app = app, Parent = gui, motion = "pulse" })
			task.wait(Arrow.timing.grow)
			local low, high = range(Arrow.timing.period, function()
				return arrow.scale.Scale
			end)
			expect(high - low > 0.04).to.equal(true)
			expect(offset(arrow)).to.equal(0)
		end)

		it("stays still for none", function()
			local arrow = Arrow.new({ app = app, Parent = gui, motion = "none" })
			task.wait(Arrow.timing.grow + 0.05)
			local low, high = range(0.3, function()
				return arrow.scale.Scale + offset(arrow)
			end)
			expect(near(low, high)).to.equal(true)
		end)

		it("with reduced motion fades in and keeps still", function()
			Preferences.setReducedMotion(true)
			local arrow = Arrow.new({ app = app, Parent = gui, motion = "bounce" })
			task.wait()
			expect(arrow.scale.Scale).to.equal(1)
			expect(arrow.fade() > 0).to.equal(true)
			local low, high = range(Arrow.timing.period * 1.5, function()
				return offset(arrow)
			end)
			expect(low).to.equal(0)
			expect(high).to.equal(0)
			expect(arrow.fade()).to.equal(0)
		end)

		it("plays again on replay and when shown again", function()
			local arrow = Arrow.new({ app = app, Parent = gui, motion = "none" })
			task.wait(Arrow.timing.grow + 0.05)
			arrow:replay()
			task.wait()
			expect(arrow.scale.Scale < 1).to.equal(true)
			task.wait(Arrow.timing.grow + 0.05)
			arrow:set("visible", false)
			task.wait()
			arrow:set("visible", true)
			task.wait()
			expect(arrow.scale.Scale < 1).to.equal(true)
		end)
	end)
end
