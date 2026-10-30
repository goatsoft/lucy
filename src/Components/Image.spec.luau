return function()
	local Image = require(script.Parent.Image)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("turns an asset id into a content url", function()
		expect(Image.url(12345)).to.equal("rbxassetid://12345")
		expect(Image.url("rbxassetid://9")).to.equal("rbxassetid://9")
		expect(Image.url("rbxthumb://type=Asset&id=1&w=150&h=150")).to.equal(
			"rbxthumb://type=Asset&id=1&w=150&h=150"
		)
		expect(Image.url(nil)).to.equal("")
		expect(Image.url(0)).to.equal("")
	end)

	it("shows an image and follows changes", function()
		local id = Reactive.ref(111)
		local image = Image.new({ app = app, Parent = gui, image = id })
		local root = image.Instance
		expect(root:IsA("ImageLabel")).to.equal(true)
		expect(root.Image).to.equal("rbxassetid://111")
		id(222)
		expect(root.Image).to.equal("rbxassetid://222")
	end)

	it("fits the image in four ways", function()
		local fit = Reactive.ref("cover")
		local image = Image.new({ app = app, Parent = gui, image = 1, fit = fit })
		local root = image.Instance
		expect(root.ScaleType).to.equal(Enum.ScaleType.Crop)
		fit("contain")
		expect(root.ScaleType).to.equal(Enum.ScaleType.Fit)
		fit("fill")
		expect(root.ScaleType).to.equal(Enum.ScaleType.Stretch)
		fit("tile")
		expect(root.ScaleType).to.equal(Enum.ScaleType.Tile)
	end)

	it("defaults to contain and rejects an unknown fit", function()
		local image = Image.new({ app = app, Parent = gui, image = 1 })
		expect(image.Instance.ScaleType).to.equal(Enum.ScaleType.Fit)
		expect(function()
			Image.new({ app = app, Parent = gui, fit = "zoom" })
		end).to.throw()
	end)

	it("takes a size and keeps an aspect ratio", function()
		local image = Image.new({
			app = app,
			Parent = gui,
			image = 1,
			size = UDim2.fromScale(1, 1),
			aspectRatio = 16 / 9,
		})
		expect(image.Instance.Size).to.equal(UDim2.fromScale(1, 1))
		local ratio = image.Instance:FindFirstChildOfClass("UIAspectRatioConstraint")
		expect(ratio).to.be.ok()
		expect(math.abs(ratio.AspectRatio - 16 / 9) < 1e-6).to.equal(true)
		local plain = Image.new({ app = app, Parent = gui, image = 1 })
		expect(plain.Instance:FindFirstChildOfClass("UIAspectRatioConstraint")).to.equal(nil)
	end)

	it("rounds its corners", function()
		local image = Image.new({ app = app, Parent = gui, image = 1, rounded = "lg" })
		expect(image.Instance:HasTag("ui-image-rounded-lg")).to.equal(true)
		expect(function()
			Image.new({ app = app, Parent = gui, rounded = "huge" })
		end).to.throw()
	end)

	it("follows a reactive visible", function()
		local visible = Reactive.ref(true)
		local image = Image.new({ app = app, Parent = gui, image = 1, visible = visible })
		visible(false)
		expect(image.Instance.Visible).to.equal(false)
	end)
end
