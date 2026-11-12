return function()
	local Aura = require(script.Parent.Aura)
	local Animate = require(script.Parent.Animate)
	local Preferences = require(script.Parent.Preferences)
	local Reactive = require(script.Parent.Reactive)
	local Server = require(script.Parent.Server)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local lastCtx: any = nil

	-- A test type: an attachment on the waist with a ParticleEmitter whose rate follows the
	-- opening, the closing and the strength; it records its context for the specs to read.
	local built = 0
	Aura.register("spec-spark", {
		intro = 1,
		outro = 0.5,
		loop = true,
		defaults = { rate = 10 },
		build = function(ctx)
			built += 1
			local at = ctx.attachment("WaistCenterAttachment")
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "Spark"
			emitter.Parent = at
			ctx.give(Reactive.watchEffect(function()
				local open = math.min(ctx.intro(), 1) * (1 - ctx.outro() / 0.5)
				emitter.Rate = ctx.option("rate") * open * ctx.strength()
			end))
			ctx.root:SetAttribute("SpecCtx", true)
			ctx.root:SetAttribute("Point", ctx.character == nil)
			lastCtx = ctx
		end,
	})
	Aura.register("spec-once", {
		intro = 0.5,
		build = function(ctx)
			ctx.attachment("RootAttachment")
		end,
	})

	-- An R15-ish stand in: a root part, a lower torso with the waist attachment, at `at`.
	local function dummy(name: string, at: Vector3): Model
		local model = Instance.new("Model")
		model.Name = name
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CFrame = CFrame.new(at)
		root.Parent = model
		local rootAtt = Instance.new("Attachment")
		rootAtt.Name = "RootAttachment"
		rootAtt.Parent = root
		local lower = Instance.new("Part")
		lower.Name = "LowerTorso"
		lower.Anchored = true
		lower.CFrame = CFrame.new(at + Vector3.new(0, -0.6, 0))
		lower.Parent = model
		local waist = Instance.new("Attachment")
		waist.Name = "WaistCenterAttachment"
		waist.Position = Vector3.new(0, 0.2, 0)
		waist.Parent = lower
		model.PrimaryPart = root
		model.Parent = workspace
		return model
	end

	local function run(seconds: number)
		for _ = 1, math.round(seconds * 60) do
			Animate.step(1 / 60)
		end
	end

	local app, cleanup
	local made: { Instance } = {}
	local function keep<T>(item: T): T
		table.insert(made, item :: any)
		return item
	end
	beforeEach(function()
		Animate.manual = true
		built = 0
		app, cleanup = Harness.app({ theme = "dark" })
	end)
	afterEach(function()
		cleanup()
		for _, item in made do
			item:Destroy()
		end
		table.clear(made)
		Animate.manual = false
		Preferences.setReducedMotion(nil)
		lastCtx = nil
	end)

	describe("types", function()
		it("needs a build to register", function()
			expect(function()
				Aura.register("spec-broken", {} :: any)
			end).to.throw()
		end)

		it("names the known types when asked for one it does not have", function()
			local ok, err = pcall(Aura.new, { app = app, type = "nope", position = Vector3.zero })
			expect(ok).to.equal(false)
			expect((string.find(tostring(err), "glow", 1, true))).to.be.ok()
		end)

		it("comes with glow: a halo, sparks and a light in a theme colour", function()
			local who = keep(dummy("SpecGlow", Vector3.new(0, 50, 0)))
			local aura = Aura.new({ app = app, type = "glow", character = who, token = "Warning" })
			run(1)
			local halo = who:FindFirstChild("Halo", true) :: BillboardGui
			local sparks = who:FindFirstChild("Sparks", true) :: ParticleEmitter
			local light = who:FindFirstChild("Light", true) :: PointLight
			expect(halo and sparks and light).to.be.ok()
			expect(halo.Parent).to.equal(sparks.Parent)
			expect((halo.Parent :: Attachment).Parent).to.equal(who.LowerTorso)
			expect(light.Color).to.equal(app.theme:resolve("Warning"))
			expect((halo:FindFirstChild("Glow") :: ImageLabel).ImageColor3).to.equal(
				app.theme:resolve("Warning")
			)
			expect(halo.Enabled).to.equal(true)
			expect(sparks.Rate > 0).to.equal(true)
			expect(light.Enabled).to.equal(true)
			aura:setStrength(0.5)
			expect(math.abs(sparks.Rate - 10) < 1e-3).to.equal(true)
			aura:finish()
			run(1)
			expect(who:FindFirstChild("Halo", true)).to.equal(nil)
		end)
	end)

	describe("a single aura", function()
		it("builds once on the character, on an attachment where the named one is", function()
			local who = keep(dummy("SpecWho", Vector3.new(0, 50, 0)))
			local aura = Aura.new({ app = app, type = "spec-spark", character = who })
			expect(built).to.equal(1)
			expect(aura.root.Parent).to.equal(who)
			expect(aura.root.Name).to.equal("LucyAura_spec-spark")
			local spark = who.LowerTorso:FindFirstChild("Spark", true) :: ParticleEmitter
			expect(spark).to.be.ok()
			local at = spark.Parent :: Attachment
			expect(at).never.to.equal(who.LowerTorso.WaistCenterAttachment)
			expect((at.WorldPosition - who.LowerTorso.WaistCenterAttachment.WorldPosition).Magnitude < 1e-3).to.equal(
				true
			)
			aura:destroy()
		end)

		it("stands at a point when given a position", function()
			local aura = Aura.new({ app = app, type = "spec-spark", position = Vector3.new(4, 60, 2) })
			expect(aura.root.Parent).to.equal(workspace)
			expect(aura.root:GetAttribute("Point")).to.equal(true)
			local spark = aura.root:FindFirstChild("Spark", true) :: ParticleEmitter
			expect(((spark.Parent :: Attachment).WorldPosition - Vector3.new(4, 60, 2)).Magnitude < 1e-3).to.equal(
				true
			)
			aura:destroy()
		end)

		it("plays its opening, then runs on", function()
			local aura = Aura.new({ app = app, type = "spec-spark", position = Vector3.new(0, 60, 0) })
			local ctx = lastCtx
			run(0.5)
			expect(math.abs(ctx.intro() - 0.5) < 0.05).to.equal(true)
			run(1)
			expect(ctx.intro()).to.equal(1)
			expect(ctx.elapsed() > 1.4).to.equal(true)
			aura:destroy()
		end)

		it("takes options over the type's defaults", function()
			local aura = Aura.new({ app = app, type = "spec-spark", position = Vector3.zero, rate = 40 })
			run(1)
			local spark = aura.root:FindFirstChild("Spark", true) :: ParticleEmitter
			expect(spark.Rate).to.equal(40)
			aura:destroy()
		end)

		it("is simply there, still, with reduced motion", function()
			Preferences.setReducedMotion(true)
			local aura = Aura.new({ app = app, type = "spec-spark", position = Vector3.zero })
			local ctx = lastCtx
			expect(ctx.intro()).to.equal(1)
			run(1)
			expect(ctx.elapsed()).to.equal(0)
			expect(ctx.reducedMotion()).to.equal(true)
			aura:destroy()
		end)

		it("closes, then leaves nothing behind", function()
			local who = keep(dummy("SpecWho", Vector3.new(0, 50, 0)))
			local done = false
			local aura = Aura.new({ app = app, type = "spec-spark", character = who })
			aura.done:Connect(function()
				done = true
			end)
			run(1)
			aura:finish()
			run(0.25)
			expect(aura.root.Parent).to.equal(who)
			run(0.5)
			expect(done).to.equal(true)
			expect(aura.root.Parent).to.equal(nil)
			expect(who:FindFirstChild("Spark", true)).to.equal(nil)
		end)

		it("goes when its character goes", function()
			local who = dummy("SpecWho", Vector3.new(0, 50, 0))
			local aura = Aura.new({ app = app, type = "spec-spark", character = who })
			who:Destroy()
			run(0.1)
			expect(aura.destroyed).to.equal(true)
		end)

		it("goes with the App", function()
			local who = keep(dummy("SpecWho", Vector3.new(0, 50, 0)))
			Aura.new({ app = app, type = "spec-spark", character = who })
			app:destroy()
			expect(who:FindFirstChild("LucyAura_spec-spark")).to.equal(nil)
			expect(who:FindFirstChild("Spark", true)).to.equal(nil)
		end)

		it("dims and stops with its strength", function()
			local aura = Aura.new({ app = app, type = "spec-spark", position = Vector3.zero })
			local ctx = lastCtx
			run(1)
			local spark = aura.root:FindFirstChild("Spark", true) :: ParticleEmitter
			local at = spark.Parent
			aura:setStrength(0.5)
			expect(spark.Rate).to.equal(5)
			aura:setStrength(0)
			expect(at.Parent).to.equal(nil)
			local was = ctx.elapsed()
			run(0.5)
			expect(ctx.elapsed()).to.equal(was) -- a stopped aura does not run
			aura:setStrength(1)
			expect(at.Parent).never.to.equal(nil)
			aura:destroy()
		end)
	end)

	describe("following the store", function()
		-- Distance is measured from here, not from wherever Studio's camera happens to be
		local function besideA()
			return Vector3.new(0, 50, 10)
		end

		local function wear(id: string, kind: string, entry: { [string]: any }?)
			app.state:set(`server.auras.{id}.{kind}`, entry or {})
		end

		it("puts on what the store says each one wears", function()
			local a = keep(dummy("SpecA", Vector3.new(0, 50, 0)))
			local follower = Aura.follow(app, {
				resolve = function(id)
					return if id == "a" then a else nil
				end,
				focus = function()
					return Vector3.new(0, 50, 10)
				end,
			})
			wear("a", "spec-spark", { options = { rate = 20 } })
			run(0.1)
			expect(a:FindFirstChild("LucyAura_spec-spark")).to.be.ok()
			expect(follower.auras["a/spec-spark"]).to.be.ok()
			app.state:remove("server.auras.a.spec-spark")
			run(0.1)
			expect(follower.auras["a/spec-spark"].finishing).to.equal(true)
			run(1)
			expect(a:FindFirstChild("LucyAura_spec-spark")).to.equal(nil)
			follower:destroy()
		end)

		it("takes a timed aura off when its time is up", function()
			local a = keep(dummy("SpecA", Vector3.new(0, 50, 0)))
			local clock = 100
			local follower = Aura.follow(app, {
				resolve = function()
					return a
				end,
				now = function()
					return clock
				end,
				focus = besideA,
			})
			wear("a", "spec-spark", { untilTime = 110 })
			run(0.1)
			expect(a:FindFirstChild("LucyAura_spec-spark")).to.be.ok()
			clock = 111
			run(1)
			expect(a:FindFirstChild("LucyAura_spec-spark")).to.equal(nil)
			follower:destroy()
		end)

		it("puts it back on after a respawn", function()
			local first = dummy("SpecA", Vector3.new(0, 50, 0))
			local current = first
			local follower = Aura.follow(app, {
				resolve = function()
					return current
				end,
				focus = besideA,
			})
			wear("a", "spec-spark")
			run(0.1)
			first:Destroy()
			current = keep(dummy("SpecA", Vector3.new(0, 50, 0)))
			run(1)
			expect(current:FindFirstChild("LucyAura_spec-spark")).to.be.ok()
			follower:destroy()
		end)

		it("runs only the nearest within its budget, fading with distance", function()
			local near = keep(dummy("SpecNear", Vector3.new(0, 50, 5)))
			local mid = keep(dummy("SpecMid", Vector3.new(0, 50, 60)))
			local far = keep(dummy("SpecFar", Vector3.new(0, 50, 30)))
			local follower = Aura.follow(app, {
				max = 2,
				near = 40,
				far = 80,
				resolve = function(id)
					return ({ near = near, mid = mid, far = far } :: any)[id]
				end,
				focus = function()
					return Vector3.new(0, 50, 0)
				end,
			})
			wear("near", "spec-once")
			wear("mid", "spec-once")
			wear("far", "spec-once")
			run(0.2)
			expect(follower.auras["near/spec-once"].strength).to.equal(1)
			expect(follower.auras["far/spec-once"].strength).to.equal(1) -- 30 studs, inside near
			expect(follower.auras["mid/spec-once"].strength).to.equal(0) -- third nearest: over the budget
			follower:destroy()
			follower = Aura.follow(app, {
				near = 40,
				far = 80,
				resolve = function(id)
					return ({ mid = mid } :: any)[id]
				end,
				focus = function()
					return Vector3.new(0, 50, 0)
				end,
			})
			run(0.2)
			expect(math.abs(follower.auras["mid/spec-once"].strength - 0.5) < 0.01).to.equal(true)
			follower:destroy()
		end)

		it("hides every aura while the game says so", function()
			local a = keep(dummy("SpecA", Vector3.new(0, 50, 0)))
			local hidden = Reactive.ref(false)
			local follower = Aura.follow(app, {
				hidden = hidden,
				resolve = function()
					return a
				end,
				focus = function()
					return Vector3.new(0, 50, 0)
				end,
			})
			wear("a", "spec-once")
			run(0.1)
			expect(follower.auras["a/spec-once"].strength).to.equal(1)
			hidden(true)
			run(0.1)
			expect(follower.auras["a/spec-once"].strength).to.equal(0)
			follower:destroy()
		end)

		it("skips a type it does not know, with one warning", function()
			local a = keep(dummy("SpecA", Vector3.new(0, 50, 0)))
			local follower = Aura.follow(app, {
				resolve = function()
					return a
				end,
			})
			wear("a", "spec-unknown")
			run(0.1)
			expect(follower.auras["a/spec-unknown"]).to.equal(nil)
			follower:destroy()
		end)
	end)

	describe("the server half", function()
		it("writes who wears what where every App sees it", function()
			local server =
				Server.new({ players = false, autoFlush = false, transport = { send = function() end } })
			Aura.wear(server, 42, "glow", { options = { token = "Warning" }, seconds = 60, now = 1000 })
			local entry = server.state:get("shared.auras.u42.glow")
			expect(entry.untilTime).to.equal(1060)
			expect(entry.options.token).to.equal("Warning")
			Aura.wear(server, "bot_3", "glow")
			expect(server.state:get("shared.auras.bot_3.glow").untilTime).to.equal(nil)
			Aura.take(server, 42, "glow")
			expect(server.state:get("shared.auras.u42")).to.equal(nil)
			Aura.take(server, "bot_3")
			expect(server.state:get("shared.auras.bot_3")).to.equal(nil)
			server:destroy()
		end)

		-- A bare UserId is all digits: the store keeps it as an array index and the client gets it
		-- back as text, so taking an aura off never reached the client. Players are u<UserId>.
		it("keeps a player under u<UserId>, given the player or the UserId", function()
			local server =
				Server.new({ players = false, autoFlush = false, transport = { send = function() end } })
			local player = { UserId = 7 }
			expect(Aura.idOf(player)).to.equal("u7")
			expect(Aura.idOf(7)).to.equal("u7")
			expect(Aura.idOf("bot_3")).to.equal("bot_3")
			Aura.wear(server, player, "glow")
			expect(server.state:get("shared.auras.u7.glow")).to.be.ok()
			Aura.take(server, player)
			expect(server.state:get("shared.auras.u7")).to.equal(nil)
			server:destroy()
		end)

		it("takes a player's aura off every App, end to end", function()
			local who = { UserId = 7, Name = "Dancer7" }
			local server, linked
			local link = {}
			function link.send(kind: string)
				if kind == "ready" and server then
					server:_ready(who)
				end
			end
			function link.call()
				return true, nil
			end
			local toClient = {}
			function toClient.send(_player: any, message: any)
				if linked then
					linked.server:_receive(message)
				end
			end
			server = Server.new({ transport = toClient, players = false, autoFlush = false })
			server:_join(who)
			local done
			linked, done = Harness.app({ namePrefix = "LucyAuraLinked_", server = { transport = link } })
			server:_ready(who)

			Aura.wear(server, who.UserId, "glow")
			server:flush()
			local worn = linked.state:get("server.auras.u7.glow")
			Aura.take(server, who.UserId, "glow")
			server:flush()
			local after = linked.state:get("server.auras")
			done()
			server:destroy()
			expect(worn).to.be.ok()
			expect(type(after) ~= "table" or next(after) == nil).to.equal(true)
		end)

		it("refuses an id that is all digits or has a dot", function()
			local server =
				Server.new({ players = false, autoFlush = false, transport = { send = function() end } })
			expect(function()
				Aura.wear(server, "42", "glow")
			end).to.throw()
			expect(function()
				Aura.wear(server, "bot.3", "glow")
			end).to.throw()
			expect(function()
				Aura.take(server, "")
			end).to.throw()
			server:destroy()
		end)

		it("finds a player's character from u<UserId> by default", function()
			expect(Aura._defaultResolve("u0")).to.equal(nil)
			expect(Aura._defaultResolve("bot_3")).to.equal(nil)
			local me = game:GetService("Players").LocalPlayer
			if me and me.Character then
				expect(Aura._defaultResolve("u" .. me.UserId)).to.equal(me.Character)
			end
		end)
	end)
end
