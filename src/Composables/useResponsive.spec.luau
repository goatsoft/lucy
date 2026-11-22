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

	describe("useResponsive", function()
		it("follows the input state, and passes plain values through", function()
			local scope = Reactive.effectScope(true)
			local gap, fixed
			local runs = 0
			scope:run(function()
				gap = Composables.useResponsive(app, { touch = 16, default = 8 })
				fixed = Composables.useResponsive(app, 4)
				Reactive.watchEffect(function()
					gap()
					runs += 1
				end)
			end)
			expect(gap()).to.equal(8)
			expect(fixed()).to.equal(4)
			app.input:setCaps(Harness.caps.mobile)
			app.input:setMode("touch")
			expect(gap()).to.equal(16)
			expect(runs).to.equal(2)
			scope:stop()
			expect(function()
				Composables.useResponsive(app, 4)
			end).to.throw()
		end)

		it("follows a getter as it is", function()
			local scope = Reactive.effectScope(true)
			local wide = Reactive.ref(false)
			local size
			scope:run(function()
				size = Composables.useResponsive(app, function()
					return if wide() then 300 else 100
				end)
			end)
			expect(size()).to.equal(100)
			wide(true)
			expect(size()).to.equal(300)
			scope:stop()
		end)
	end)
end
