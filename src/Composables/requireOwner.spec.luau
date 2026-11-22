return function()
	local Composables = require(script.Parent)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app()
	end)
	afterEach(function()
		cleanup()
	end)

	it("needs an owner", function()
		expect(function()
			Composables.useDensity(app)
		end).to.throw()
		expect(function()
			Composables.useBackHandler(app, true, function()
				return true
			end)
		end).to.throw()
	end)
end
