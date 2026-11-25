return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local World = require(script.Parent.Parent.Core.World)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app()
	end)
	afterEach(function()
		cleanup()
	end)

	describe("useProximity", function()
		it("needs an owner", function()
			expect(function()
				Composables.useProximity(app, Vector3.zero)
			end).to.throw()
		end)

		it("is active within the distance, and needs a little more to leave", function()
			local at = Vector3.new(20, 0, 0)
			local scope = Reactive.effectScope(true)
			scope:run(function()
				local near = Composables.useProximity(app, Vector3.zero, {
					distance = 10,
					hysteresis = 1,
					origin = function()
						return at
					end,
				})
				near.check()
				expect(near.active()).to.equal(false)
				expect(near.distance()).to.equal(20)
				at = Vector3.new(9, 0, 0)
				near.check()
				expect(near.active()).to.equal(true)
				at = Vector3.new(10.5, 0, 0)
				near.check()
				expect(near.active()).to.equal(true)
				at = Vector3.new(11.5, 0, 0)
				near.check()
				expect(near.active()).to.equal(false)
			end)
			scope:stop()
		end)

		it("measures from parts, attachments and models (World.positionOf)", function()
			local part = Instance.new("Part")
			part.Position = Vector3.new(0, 0, 5)
			local attachment = Instance.new("Attachment")
			attachment.Position = Vector3.new(0, 0, 1)
			attachment.Parent = part
			local model = Instance.new("Model")
			local inModel = part:Clone()
			inModel.Parent = model
			model.PrimaryPart = inModel
			expect(World.positionOf(part)).to.equal(Vector3.new(0, 0, 5))
			expect(World.positionOf(attachment)).to.equal(Vector3.new(0, 0, 6))
			expect(World.positionOf(model)).to.equal(Vector3.new(0, 0, 5))
			expect(World.positionOf(Vector3.one)).to.equal(Vector3.one)
			expect(World.positionOf(nil)).to.equal(nil)
			part:Destroy()
			model:Destroy()
		end)

		it("is off with no character", function()
			local scope = Reactive.effectScope(true)
			scope:run(function()
				local near = Composables.useProximity(app, Vector3.zero, {
					distance = 10,
					origin = function()
						return nil
					end,
				})
				near.check()
				expect(near.active()).to.equal(false)
				expect(near.distance()).to.equal(math.huge)
			end)
			scope:stop()
		end)

		it("follows a distance that changes", function()
			local distance = Reactive.ref(5)
			local scope = Reactive.effectScope(true)
			scope:run(function()
				local near = Composables.useProximity(app, Vector3.zero, {
					distance = distance,
					origin = function()
						return Vector3.new(8, 0, 0)
					end,
				})
				near.check()
				expect(near.active()).to.equal(false)
				distance(10)
				near.check()
				expect(near.active()).to.equal(true)
			end)
			scope:stop()
		end)

		it("shares one loop per app and lets it go when the last one stops", function()
			local a = Reactive.effectScope(true)
			local b = Reactive.effectScope(true)
			a:run(function()
				Composables.useProximity(app, Vector3.zero, { distance = 1 })
			end)
			b:run(function()
				Composables.useProximity(app, Vector3.zero, { distance = 1 })
			end)
			expect(#app._lucyProximity.watchers).to.equal(2)
			a:stop()
			expect(#app._lucyProximity.watchers).to.equal(1)
			b:stop()
			expect(#app._lucyProximity.watchers).to.equal(0)
		end)
	end)
end
