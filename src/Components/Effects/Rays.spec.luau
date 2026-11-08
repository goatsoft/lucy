return function()
	local Effect = require(script.Parent.Parent.Effect)
	local Animate = require(script.Parent.Parent.Parent.Core.Animate)
	local Preferences = require(script.Parent.Parent.Parent.Core.Preferences)
	local Harness = require(script.Parent.Parent.Parent.Testing.Harness)
	local Textures = require(script.Parent.Textures)

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

	-- A layer's average transparency now
	local function seen(fx: any, layer: number): number
		local total = 0
		for _, ray in fx.layers[layer].rays do
			total += ray.ImageTransparency
		end
		return total / #fx.layers[layer].rays
	end

	it("draws layers of rays round the middle, back to front: fewer, shorter and wider", function()
		local fx = rays({ count = 16 })
		expect(#fx.layers).to.equal(3)
		local back, front = fx.layers[1], fx.layers[3]
		expect(#back.rays).to.equal(16)
		expect(#front.rays < #back.rays).to.equal(true)
		expect(#fx.rays).to.equal(#back.rays + #fx.layers[2].rays + #front.rays)
		run(1.5)
		expect(front.rays[1].Size.Y.Scale < back.rays[1].Size.Y.Scale).to.equal(true)
		expect(front.rays[1].Size.X.Scale > back.rays[1].Size.X.Scale).to.equal(true)
		expect(math.abs(back.arms[2].Rotation - back.arms[1].Rotation - 22.5) < 1e-3).to.equal(true)
	end)

	it("draws each ray with the streak texture, its base at the middle", function()
		local ray = rays({ count = 4 }).layers[1].rays[1]
		expect(ray:IsA("ImageLabel")).to.equal(true)
		expect(ray.Image).to.equal(Textures.streak)
		expect(ray.AnchorPoint).to.equal(Vector2.new(0.5, 1))
	end)

	it("tags each layer, the front one too", function()
		local fx = rays({ count = 8 })
		local back, front = fx.layers[1].rays[1], fx.layers[3].rays[1]
		expect(back:HasTag("ui-effect-rays-ray")).to.equal(true)
		expect(back:HasTag("ui-effect-rays-layer-1")).to.equal(true)
		expect(front:HasTag("ui-effect-rays-front")).to.equal(true)
		expect(back:HasTag("ui-effect-rays-front")).to.equal(false)
	end)

	it("takes how many layers to draw", function()
		local fx = rays({ layers = 1, count = 6 })
		expect(#fx.layers).to.equal(1)
		expect(#fx.rays).to.equal(6)
	end)

	it("defaults to twelve rays at the back and a four point glint at the front", function()
		local fx = rays()
		expect(#fx.layers[1].rays).to.equal(12)
		expect(#fx.layers[3].rays).to.equal(4)
	end)

	it("is dimmer further out: the back layer more see-through than the front", function()
		local fx = rays({ count = 8, pulse = false })
		run(1.5)
		expect(seen(fx, 1) > seen(fx, 2)).to.equal(true)
		expect(seen(fx, 2) > seen(fx, 3)).to.equal(true)
	end)

	it("gleams: the burst swells a little, and each ray flares at its own moment", function()
		local fx = rays({ count = 8 })
		run(1.5)
		local scale = fx.pulse.Scale
		local ray = fx.layers[1].rays[1]
		local lowest, highest = math.huge, -math.huge
		local apart = false
		for _ = 1, 40 do
			run(0.1)
			lowest = math.min(lowest, ray.ImageTransparency)
			highest = math.max(highest, ray.ImageTransparency)
			if math.abs(ray.ImageTransparency - fx.layers[1].rays[2].ImageTransparency) > 1e-3 then
				apart = true
			end
		end
		expect(math.abs(fx.pulse.Scale - scale) > 1e-4).to.equal(true)
		expect(highest - lowest > 0.1).to.equal(true)
		expect(apart).to.equal(true)
	end)

	it("holds steady with pulse = false", function()
		local fx = rays({ count = 8, pulse = false })
		run(1.5)
		local ray = fx.layers[1].rays[1]
		local before = ray.ImageTransparency
		run(0.4)
		expect(fx.pulse.Scale).to.equal(1)
		expect(ray.ImageTransparency).to.equal(before)
	end)

	it("glows in the middle, a hot centre in a softer glow, unless core = false", function()
		local fx = rays({ count = 8 })
		run(1.5)
		expect(#fx.core).to.equal(2)
		local outer, hot = fx.core[1], fx.core[2]
		expect(outer.Image).to.equal(Textures.glow)
		expect(hot:HasTag("ui-effect-rays-hot")).to.equal(true)
		expect(hot.ZIndex > outer.ZIndex).to.equal(true)
		expect(#rays({ core = false }).core).to.equal(0)
	end)

	it("fans out from the middle when shown", function()
		local fx = rays({ count = 4 })
		local ray = fx.layers[1].rays[1]
		expect(ray.Size.Y.Scale < 0.1).to.equal(true)
		run(1.5)
		expect(math.abs(ray.Size.Y.Scale - 0.5) < 1e-3).to.equal(true)
		expect(fx.layers[3].rays[1].Size.Y.Scale > 0.2).to.equal(true)
	end)

	it("turns at spin degrees a second, the middle layer the other way", function()
		local fx = rays({ spin = 30 })
		local back, middle = fx.layers[1].wheel, fx.layers[2].wheel
		local b0, m0 = back.Rotation, middle.Rotation
		run(1)
		expect(math.abs(back.Rotation - b0 - 30) < 0.6).to.equal(true)
		expect(((middle.Rotation - m0) % 360) > 180).to.equal(true)
	end)

	it("play() fans the rays out again", function()
		local fx = rays({ count = 4 })
		local ray = fx.layers[1].rays[1]
		run(1.5)
		fx:play()
		expect(ray.Size.Y.Scale < 0.1).to.equal(true)
		run(1.5)
		expect(math.abs(ray.Size.Y.Scale - 0.5) < 1e-3).to.equal(true)
	end)

	it("holds still and full with reduced motion", function()
		Preferences.setReducedMotion(true)
		local fx = rays({ count = 4 })
		expect(math.abs(fx.layers[1].rays[1].Size.Y.Scale - 0.5) < 1e-3).to.equal(true)
		local before = fx.layers[1].wheel.Rotation
		run(1)
		expect(fx.layers[1].wheel.Rotation).to.equal(before)
	end)

	it("colours its rays and glow by the variant", function()
		local fx = rays({ variant = "warning" })
		expect(fx.layers[1].rays[1]:HasTag("ui-effect-rays-ray-warning")).to.equal(true)
		expect(fx.core[1]:HasTag("ui-effect-rays-ray-warning")).to.equal(true)
	end)
end
