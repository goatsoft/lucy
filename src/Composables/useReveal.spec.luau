return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)

	describe("useReveal / useCount", function()
		local Animate = require(script.Parent.Parent.Core.Animate)

		beforeEach(function()
			Animate.manual = true
		end)
		afterEach(function()
			Animate.manual = false
		end)

		local function run(seconds: number)
			for _ = 1, math.round(seconds * 60) do
				Animate.step(1 / 60)
			end
		end

		local function owned(fn: () -> any): (any, any)
			local scope = Reactive.effectScope(true)
			local result
			scope:run(function()
				result = fn()
			end)
			return result, scope
		end

		it("useReveal shows a text a character at a time, again when it changes", function()
			local line = Reactive.ref("Hello there")
			local typed, scope = owned(function()
				return Composables.useReveal(line, { rate = 10 })
			end)
			expect(typed.visible()).to.equal(0)
			expect(typed.revealing()).to.equal(true)
			run(0.5)
			expect(typed.visible()).to.equal(5)
			local done = 0
			typed.done:Connect(function()
				done += 1
			end)
			run(1)
			expect(typed.visible()).to.equal(-1) -- all of it
			expect(typed.revealing()).to.equal(false)
			expect(done).to.equal(1)
			line("Again")
			expect(typed.visible()).to.equal(0)
			typed.skip()
			expect(typed.visible()).to.equal(-1)
			expect(done).to.equal(2)
			scope:stop()
		end)

		it("useReveal counts rich text by what a reader sees", function()
			local typed, scope = owned(function()
				return Composables.useReveal("<b>Hey</b> &amp; you", { rate = 10, rich = true })
			end)
			run(0.8)
			expect(typed.visible()).to.equal(8)
			run(0.2)
			expect(typed.visible()).to.equal(-1) -- "Hey & you" is 9
			scope:stop()
		end)

		it("useCount eases a number to its value, on from where it is when it changes", function()
			local xp = Reactive.ref(100)
			local count, scope = owned(function()
				return Composables.useCount(xp, { seconds = 1 })
			end)
			expect(count.value()).to.equal(0)
			expect(count.counting()).to.equal(true)
			run(0.5)
			expect(count.value() > 50 and count.value() < 100).to.equal(true) -- eases out: past half way
			run(0.6)
			expect(count.value()).to.equal(100)
			expect(count.counting()).to.equal(false)
			xp(250)
			run(0.3)
			expect(count.value() > 100 and count.value() < 250).to.equal(true)
			local done = 0
			count.done:Connect(function()
				done += 1
			end)
			count.skip()
			expect(count.value()).to.equal(250)
			expect(done).to.equal(1)
			scope:stop()
		end)

		it("useCount starts from `from`, and needs an owner", function()
			local count, scope = owned(function()
				return Composables.useCount(50, { seconds = 1, from = 40 })
			end)
			expect(count.value()).to.equal(40)
			run(1.1)
			expect(count.value()).to.equal(50)
			scope:stop()
			expect(function()
				Composables.useCount(1)
			end).to.throw()
			expect(function()
				Composables.useReveal("x")
			end).to.throw()
		end)
	end)
end
