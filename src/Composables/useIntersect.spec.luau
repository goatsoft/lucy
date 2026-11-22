return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app()
	end)
	afterEach(function()
		cleanup()
	end)

	describe("useIntersect", function()
		-- A 200 x 100 scroll area over a 1000 px canvas, and a card at `y`
		local function track(y: number): (ScrollingFrame, Frame)
			local frame = Instance.new("ScrollingFrame")
			frame.Size = UDim2.fromOffset(200, 100)
			frame.CanvasSize = UDim2.fromOffset(0, 1000)
			local card = Instance.new("Frame")
			card.Size = UDim2.fromOffset(50, 40)
			card.Position = UDim2.fromOffset(0, y)
			card.Parent = frame
			frame.Parent = Harness.mount(app)
			return frame, card
		end

		it("needs an owner", function()
			expect(function()
				Composables.useIntersect(Instance.new("Frame"))
			end).to.throw()
		end)

		it("turns true when the target is scrolled near, and stays true", function()
			if not Harness.laysOutLive() then
				return
			end
			local frame, card = track(500)
			local scope = Reactive.effectScope(true)
			local reached = scope:run(Composables.useIntersect, card)
			for _ = 1, 4 do
				task.wait()
			end
			expect(reached()).to.equal(false)
			frame.CanvasPosition = Vector2.new(0, 450)
			expect(Harness.waitFor(reached)).to.equal(true)
			frame.CanvasPosition = Vector2.new(0, 0)
			task.wait()
			task.wait()
			expect(reached()).to.equal(true)
			scope:stop()
		end)

		it("takes its target from a ref set later, and a handle", function()
			if not Harness.laysOutLive() then
				return
			end
			local _, card = track(20)
			local target = Reactive.ref(nil :: any)
			local scope = Reactive.effectScope(true)
			local reached = scope:run(Composables.useIntersect, target)
			expect(reached()).to.equal(false)
			target({ Instance = card })
			expect(Harness.waitFor(reached)).to.equal(true)
			scope:stop()
		end)

		it("does not look until it is enabled", function()
			if not Harness.laysOutLive() then
				return
			end
			local _, card = track(20)
			local placed = Reactive.ref(false)
			local scope = Reactive.effectScope(true)
			local reached = scope:run(Composables.useIntersect, card, { enabled = placed })
			for _ = 1, 4 do
				task.wait()
			end
			expect(reached()).to.equal(false)
			placed(true)
			expect(Harness.waitFor(reached)).to.equal(true)
			scope:stop()
		end)

		it("stops looking with its owner", function()
			if not Harness.laysOutLive() then
				return
			end
			local frame, card = track(500)
			local scope = Reactive.effectScope(true)
			local reached = scope:run(Composables.useIntersect, card)
			scope:stop()
			frame.CanvasPosition = Vector2.new(0, 450)
			for _ = 1, 4 do
				task.wait()
			end
			expect(reached()).to.equal(false)
		end)
	end)
end
