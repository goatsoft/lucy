return function()
	local Effect = require(script.Parent.Effect)
	local Animate = require(script.Parent.Parent.Core.Animate)
	local Element = require(script.Parent.Parent.Core.Element)
	local Preferences = require(script.Parent.Parent.Core.Preferences)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	-- A test type: a dot that grows over a 1 s opening and, looping, records how long it has run
	Effect.register("spec-dot", {
		intro = 1,
		loop = true,
		defaults = { grow = 0.5 },
		render = function(ctx)
			ctx.handle.ctx = ctx
			return Element.new("Frame", {
				Name = "Dot",
				Size = function()
					local s = ctx.option("grow") * math.min(ctx.intro(), 1)
					return UDim2.fromScale(s, s)
				end,
			})
		end,
	})
	Effect.register("spec-once", {
		intro = 0.5,
		render = function(ctx)
			ctx.handle.ctx = ctx
			return Element.new("Frame", { Name = "Once" })
		end,
	})

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

	it("draws its type in a square stage centred in its box", function()
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-dot" })
		expect(fx.stage:FindFirstChildOfClass("UIAspectRatioConstraint")).to.be.ok()
		expect(fx.stage.AnchorPoint).to.equal(Vector2.new(0.5, 0.5))
		expect(fx.content.Name).to.equal("Dot")
		expect(fx.content.Parent).to.equal(fx.stage)
		expect(fx.Instance:HasTag("ui-effect")).to.equal(true)
		expect(fx.Instance:HasTag("ui-effect-spec-dot")).to.equal(true)
		expect(fx.Instance:HasTag("ui-effect-primary")).to.equal(true)
	end)

	it("plays its opening when shown, and keeps a looping type running", function()
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-dot" })
		local ctx = fx.ctx
		expect(ctx.intro()).to.equal(0)
		run(0.5)
		expect(math.abs(ctx.intro() - 0.5) < 0.02).to.equal(true)
		run(1)
		expect(ctx.intro()).to.equal(1) -- the opening stops at its end
		expect(ctx.elapsed() > 1.4).to.equal(true) -- a loop keeps counting
		expect(fx.running).to.equal(true)
	end)

	it("stops a type that does not loop once its opening is done", function()
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-once" })
		run(1)
		expect(fx.ctx.intro()).to.equal(0.5)
		expect(fx.running).to.equal(false)
	end)

	it("play() replays the opening", function()
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-dot" })
		run(1.5)
		fx:play()
		expect(fx.ctx.intro()).to.equal(0)
		run(0.5)
		expect(math.abs(fx.ctx.intro() - 0.5) < 0.02).to.equal(true)
	end)

	it("runs only while visible, and opens again when shown", function()
		local visible = Reactive.ref(true)
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-dot", visible = visible })
		run(1.5)
		visible(false)
		expect(fx.running).to.equal(false)
		local held = fx.ctx.elapsed()
		run(1)
		expect(fx.ctx.elapsed()).to.equal(held)
		visible(true)
		expect(fx.ctx.intro()).to.equal(0)
		expect(fx.running).to.equal(true)
	end)

	it("is simply there and still with reduced motion", function()
		Preferences.setReducedMotion(true)
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-dot" })
		expect(fx.ctx.intro()).to.equal(1)
		run(1)
		expect(fx.ctx.elapsed()).to.equal(0)
		expect(fx.running).to.equal(false)
	end)

	it("is simply there and still with still = true, and play does not move it", function()
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-dot", still = true })
		expect(fx.ctx.intro()).to.equal(1)
		run(1)
		expect(fx.ctx.elapsed()).to.equal(0)
		expect(fx.running).to.equal(false)
		fx:play()
		expect(fx.ctx.intro()).to.equal(1)
		expect(fx.running).to.equal(false)
	end)

	it("reads a type's options over its defaults", function()
		local a = Effect.new({ app = app, Parent = gui, type = "spec-dot" })
		local b = Effect.new({ app = app, Parent = gui, type = "spec-dot", grow = 0.8 })
		expect(a.ctx.option("grow")).to.equal(0.5)
		expect(b.ctx.option("grow")).to.equal(0.8)
	end)

	it("follows its variant, and refuses unknown variants and types", function()
		local variant = Reactive.ref("primary")
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-dot", variant = variant })
		variant("warning")
		expect(fx.Instance:HasTag("ui-effect-warning")).to.equal(true)
		expect(fx.ctx.variant()).to.equal("warning")
		expect(function()
			Effect.new({ app = app, Parent = gui, type = "spec-dot", variant = "nope" })
		end).to.throw()
		expect(function()
			Effect.new({ app = app, Parent = gui, type = "no-such-effect" })
		end).to.throw()
	end)

	it("stops on destroy", function()
		local fx = Effect.new({ app = app, Parent = gui, type = "spec-dot" })
		local root = fx.Instance
		fx:destroy()
		expect(fx.running).to.equal(false)
		expect(root.Parent).to.equal(nil)
	end)

	it("comes with rays built in", function()
		expect(Effect.types.rays).to.be.ok()
	end)
end
