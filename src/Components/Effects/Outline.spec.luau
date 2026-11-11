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

	local function outline(props: { [string]: any }?)
		local p = props or {}
		p.app, p.Parent, p.type = app, gui, "outline"
		return Effect.new(p)
	end

	local function stroke(part: Instance): UIStroke
		return part:FindFirstChildOfClass("UIStroke") :: UIStroke
	end

	it("fills its box, whatever the shape: the stage is not kept square", function()
		local fx = outline({ size = UDim2.fromOffset(240, 48) })
		expect(fx.stage:FindFirstChildOfClass("UIAspectRatioConstraint")).to.equal(nil)
		local rays = Effect.new({ app = app, Parent = gui, type = "rays" })
		expect(rays.stage:FindFirstChildOfClass("UIAspectRatioConstraint")).to.be.ok()
	end)

	it("draws a glow, a rim and a running light, with the corner radius asked for", function()
		local fx = outline({ radius = 14, thickness = 3 })
		expect(fx.glow).to.be.ok()
		expect(fx.rim).to.be.ok()
		expect(fx.light).to.be.ok()
		expect((fx.rim:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).to.equal(UDim.new(0, 14))
		expect(stroke(fx.rim).Thickness).to.equal(3)
		expect(stroke(fx.glow).Thickness > 3).to.equal(true)
	end)

	it("fades in, then the light runs round the rim", function()
		local fx = outline({ speed = 90 })
		expect(stroke(fx.rim).Transparency).to.equal(1)
		run(1)
		expect(stroke(fx.rim).Transparency < 1).to.equal(true)
		expect(stroke(fx.light).Transparency).to.equal(0)
		local before = fx.sweep.Rotation
		run(0.5)
		expect(fx.sweep.Rotation ~= before).to.equal(true)
	end)

	it("leaves out the running light at speed 0 and the glow with glow = false", function()
		local fx = outline({ speed = 0, glow = false })
		expect(fx.light).to.equal(nil)
		expect(fx.glow).to.equal(nil)
		expect(fx.rim).to.be.ok()
	end)

	it("is there and still with still = true", function()
		local fx = outline({ still = true })
		run(1)
		expect(stroke(fx.rim).Transparency < 1).to.equal(true)
		expect(fx.sweep.Rotation).to.equal(0)
		expect(fx.running).to.equal(false)
	end)

	it("takes its colour from the variant", function()
		local fx = outline({ variant = "warning" })
		expect(fx.rim:HasTag("ui-effect-outline-warning")).to.equal(true)
		app.state:set(`ui.{fx.id}.variant`, "success")
		expect(fx.rim:HasTag("ui-effect-outline-success")).to.equal(true)
		expect(fx.rim:HasTag("ui-effect-outline-warning")).to.equal(false)
	end)
end
