return function()
	local Skeleton = require(script.Parent.Skeleton)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("follows a reactive visible", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local loading = Reactive.ref(true)
		local skeleton = Skeleton.new({ app = app, Parent = gui, visible = loading })
		expect(skeleton.pulsing).to.equal(true)
		loading(false)
		expect(skeleton.pulsing).to.equal(false)
		expect(skeleton.Instance.Visible).to.equal(false)
	end)

	it("pulses while visible and stops when hidden", function()
		local skeleton = Skeleton.new({ app = app, Parent = gui })
		expect(skeleton.pulsing).to.equal(true)
		skeleton:set({ visible = false })
		expect(skeleton.pulsing).to.equal(false)
	end)

	it("can be a circle", function()
		local skeleton =
			Skeleton.new({ app = app, Parent = gui, circle = true, size = UDim2.fromOffset(48, 48) })
		expect(skeleton.Instance:HasTag("ui-skeleton-circle")).to.equal(true)
		expect(skeleton.Instance.Size).to.equal(UDim2.fromOffset(48, 48))
	end)
end
