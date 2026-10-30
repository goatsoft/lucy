return function()
	local ScrollArea = require(script.Parent.ScrollArea)
	local Scroll = require(script.Parent.Parent.Core.Scroll)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local function block(height: number): Frame
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, height)
		return frame
	end

	it("is a tagged ScrollingFrame with its children in a content frame", function()
		local a = block(40)
		local area = ScrollArea.new({ app = app, Parent = gui, children = { a } })
		expect(area.Instance.ClassName).to.equal("ScrollingFrame")
		expect(area.Instance:HasTag("ui-scroll-area")).to.equal(true)
		expect(a.Parent).to.equal(area.content)
		expect(area.content.Parent).to.equal(area.Instance)
	end)

	it("fills its parent and scrolls vertically by default", function()
		local area = ScrollArea.new({ app = app, Parent = gui })
		expect(area.Instance.Size).to.equal(UDim2.fromScale(1, 1))
		expect(area.Instance.ScrollingDirection).to.equal(Enum.ScrollingDirection.Y)
		expect(area.Instance.AutomaticCanvasSize).to.equal(Enum.AutomaticSize.Y)
		expect(area.content.AutomaticSize).to.equal(Enum.AutomaticSize.Y)
	end)

	it("scrolls horizontally or both ways", function()
		local row = ScrollArea.new({ app = app, Parent = gui, direction = "horizontal" })
		expect(row.Instance.ScrollingDirection).to.equal(Enum.ScrollingDirection.X)
		expect(row.Instance.AutomaticCanvasSize).to.equal(Enum.AutomaticSize.X)
		expect(row.content.AutomaticSize).to.equal(Enum.AutomaticSize.X)
		local both = ScrollArea.new({ app = app, Parent = gui, direction = "both" })
		expect(both.Instance.ScrollingDirection).to.equal(Enum.ScrollingDirection.XY)
		expect(both.Instance.AutomaticCanvasSize).to.equal(Enum.AutomaticSize.XY)
	end)

	it("rejects an unknown direction", function()
		expect(function()
			ScrollArea.new({ app = app, Parent = gui, direction = "diagonal" })
		end).to.throw()
	end)

	it("takes a size", function()
		local area = ScrollArea.new({ app = app, Parent = gui, size = UDim2.fromOffset(300, 200) })
		expect(area.Instance.Size).to.equal(UDim2.fromOffset(300, 200))
	end)

	it("pads its content", function()
		local area = ScrollArea.new({ app = app, Parent = gui, padding = 12 })
		local pad = area.content:FindFirstChildOfClass("UIPadding")
		expect(pad).to.be.ok()
		expect(pad.PaddingTop).to.equal(UDim.new(0, 12))
		expect(pad.PaddingLeft).to.equal(UDim.new(0, 12))
	end)

	it("follows a reactive visible", function()
		local shown = Reactive.ref(true)
		local area = ScrollArea.new({ app = app, Parent = gui, visible = shown })
		expect(area.Instance.Visible).to.equal(true)
		shown(false)
		expect(area.Instance.Visible).to.equal(false)
	end)

	it("fits short content when given a maxHeight", function()
		local child = block(60)
		local area = ScrollArea.new({
			app = app,
			Parent = gui,
			size = UDim2.fromOffset(200, 0),
			maxHeight = 150,
			children = { child },
		})
		Harness.flush()
		local frame = area.Instance
		expect(math.abs(frame.AbsoluteSize.Y - area.content.AbsoluteSize.Y) < 1).to.equal(true)
		expect(frame.Size.X).to.equal(UDim.new(0, 200))
	end)

	it("stops at maxHeight and scrolls past it, and grows again as content changes", function()
		local child = block(60)
		local area = ScrollArea.new({
			app = app,
			Parent = gui,
			size = UDim2.fromOffset(200, 0),
			maxHeight = 150,
			children = { child },
		})
		Harness.flush()
		child.Size = UDim2.new(1, 0, 0, 400)
		Harness.flush()
		local frame = area.Instance
		local scale = Scroll.scaleOf(frame)
		expect(math.abs(frame.AbsoluteSize.Y - 150 * scale) < 1).to.equal(true)
		expect(frame.AbsoluteCanvasSize.Y > frame.AbsoluteWindowSize.Y).to.equal(true)
		child.Size = UDim2.new(1, 0, 0, 80)
		Harness.flush()
		expect(math.abs(frame.AbsoluteSize.Y - area.content.AbsoluteSize.Y) < 1).to.equal(true)
	end)

	it("follows a reactive maxHeight", function()
		local cap = Reactive.ref(150)
		local area = ScrollArea.new({
			app = app,
			Parent = gui,
			size = UDim2.fromOffset(200, 0),
			maxHeight = cap,
			children = { block(400) },
		})
		Harness.flush()
		cap(100)
		Harness.flush()
		local frame = area.Instance
		expect(math.abs(frame.AbsoluteSize.Y - 100 * Scroll.scaleOf(frame)) < 1).to.equal(true)
	end)

	it("lets gamepad selection pass to its children", function()
		local area = ScrollArea.new({ app = app, Parent = gui })
		expect(area.Instance.Selectable).to.equal(false)
	end)
end
