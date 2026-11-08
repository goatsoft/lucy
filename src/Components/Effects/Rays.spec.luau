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

	local function rays(props: { [string]: any }?)
		local p = props or {}
		p.app, p.Parent, p.type = app, gui, "rays"
		return Effect.new(p)
	end

	it("draws its rays round the middle, every other one fainter", function()
		local fx = rays({ count = 8 })
		expect(#fx.rays).to.equal(8)
		expect(#fx.arms).to.equal(8)
		expect(fx.rays[1]:HasTag("ui-effect-rays-ray")).to.equal(true)
		expect(fx.rays[2]:HasTag("ui-effect-rays-ray-alt")).to.equal(true)
		expect(fx.rays[1]:HasTag("ui-effect-rays-ray-alt")).to.equal(false)
		expect(math.abs(fx.arms[2].Rotation - fx.arms[1].Rotation - 45) < 1e-3).to.equal(true)
	end)

	it("defaults to twelve rays", function()
		expect(#rays().rays).to.equal(12)
	end)

	it("fans out from the middle when shown", function()
		local fx = rays({ count = 4 })
		expect(fx.rays[1].Size.Y.Scale < 0.1).to.equal(true)
		run(1.5)
		expect(math.abs(fx.rays[1].Size.Y.Scale - 0.5) < 1e-3).to.equal(true)
		expect(math.abs(fx.rays[4].Size.Y.Scale - 0.5) < 1e-3).to.equal(true)
	end)

	it("turns at spin degrees a second", function()
		local fx = rays({ spin = 30 })
		local before = fx.wheel.Rotation
		run(1)
		expect(math.abs(fx.wheel.Rotation - before - 30) < 0.6).to.equal(true)
	end)

	it("play() fans the rays out again", function()
		local fx = rays({ count = 4 })
		run(1.5)
		fx:play()
		expect(fx.rays[1].Size.Y.Scale < 0.1).to.equal(true)
		run(1.5)
		expect(math.abs(fx.rays[1].Size.Y.Scale - 0.5) < 1e-3).to.equal(true)
	end)

	it("holds still and full with reduced motion", function()
		Preferences.setReducedMotion(true)
		local fx = rays({ count = 4 })
		expect(math.abs(fx.rays[1].Size.Y.Scale - 0.5) < 1e-3).to.equal(true)
		local before = fx.wheel.Rotation
		run(1)
		expect(fx.wheel.Rotation).to.equal(before)
	end)

	it("colours its rays by the variant", function()
		local fx = rays({ variant = "warning" })
		expect(fx.rays[1]:HasTag("ui-effect-rays-ray-warning")).to.equal(true)
	end)
end
