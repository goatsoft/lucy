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

	describe("useBackHandler", function()
		it("is on the back stack only while active", function()
			local scope = Reactive.effectScope(true)
			local open = Reactive.ref(false)
			local calls = 0
			scope:run(function()
				Composables.useBackHandler(app, open, function()
					calls += 1
					return true
				end)
			end)
			app.input:back()
			expect(calls).to.equal(0)
			open(true)
			expect(app.input:back()).to.equal(true)
			expect(calls).to.equal(1)
			open(false)
			app.input:back()
			expect(calls).to.equal(1)
			open(true)
			scope:stop()
			app.input:back()
			expect(calls).to.equal(1)
		end)
	end)
end
