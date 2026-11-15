return function()
	local Effect = require(script.Parent.Parent.Effect)
	local Animate = require(script.Parent.Parent.Parent.Core.Animate)
	local Preferences = require(script.Parent.Parent.Parent.Core.Preferences)
	local Harness = require(script.Parent.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		Animate.manual = true
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
		Animate.manual = false
		Preferences.setReducedMotion(nil)
	end)

	local function run(seconds: number)
		for _ = 1, math.round(seconds * 60) do
			Animate.step(1 / 60)
		end
	end

	local function shine(props: { [string]: any }?)
		local p = props or {}
		p.app, p.Parent, p.type = app, gui, "shine"
		return Effect.new(p)
	end

	it("fills its box and keeps the light inside, clear of the rounded corners", function()
		local fx = shine({ size = UDim2.fromOffset(240, 48), radius = 12 })
		expect(fx.stage:FindFirstChildOfClass("UIAspectRatioConstraint")).to.equal(nil)
		expect(fx.clip.ClipsDescendants).to.equal(true)
		-- Inset from each edge by a share of the radius
		expect(fx.clip.Size).to.equal(UDim2.new(1, -8, 1, -8))
		expect(fx.glint.Parent).to.equal(fx.clip)
	end)

	it("sweeps a glint across from left to right, then rests until the next", function()
		local fx = shine({ every = 2, sweep = 0.5, width = 0.25 })
		run(0.1)
		expect(fx.glint.Visible).to.equal(true)
		local early = fx.glint.Position.X.Scale
		run(0.25)
		local later = fx.glint.Position.X.Scale
		expect(later > early).to.equal(true)
		run(0.5)
		expect(fx.glint.Visible).to.equal(false)
		run(1.25)
		expect(fx.glint.Visible).to.equal(true)
	end)

	it("leans the band and lights it brightest in its middle", function()
		local fx = shine({ slant = 30, strength = 0.8 })
		expect(fx.glint.Rotation).to.equal(30)
		local points = fx.fade.Transparency.Keypoints
		expect(points[1].Value).to.equal(1)
		expect(points[#points].Value).to.equal(1)
		expect(math.abs(points[3].Value - 0.2) < 1e-6).to.equal(true)
	end)

	it("warms the light for warning", function()
		local fx = shine({ variant = "warning" })
		expect(fx.glint:HasTag("ui-effect-shine-warning")).to.equal(true)
	end)

	it("does not move with reduced motion", function()
		Preferences.setReducedMotion(true)
		local fx = shine()
		local before = fx.glint.Position
		run(1)
		expect(fx.glint.Position).to.equal(before)
		expect(fx.running).to.equal(false)
	end)
end
