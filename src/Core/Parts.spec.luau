return function()
	local Parts = require(script.Parent.Parts)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Button = require(script.Parent.Parent.Components.Button)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("goes up from an owned part to its component, wherever the part sits", function()
		local button = Button.new({ app = app, Parent = gui })
		local elsewhere = Instance.new("Frame")
		elsewhere.Parent = gui
		local part = Instance.new("Frame")
		part.Parent = elsewhere
		Parts.own(button, part)
		expect(Parts.parent(app, part)).to.equal(button.Instance)
	end)

	it("goes to the Parent for anything else, or once the component is gone", function()
		local holder = Instance.new("Frame")
		holder.Parent = gui
		local plain = Instance.new("Frame")
		plain.Parent = holder
		expect(Parts.parent(app, plain)).to.equal(holder)
		local button = Button.new({ app = app, Parent = gui })
		local part = Instance.new("Frame")
		part.Parent = holder
		Parts.own(button, part)
		button:destroy()
		expect(Parts.parent(app, part)).to.equal(holder)
	end)
end
