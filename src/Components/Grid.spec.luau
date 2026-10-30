return function()
	local Grid = require(script.Parent.Grid)
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

	-- A plain frame of a known width to put a grid in.
	local function box(width: number): Frame
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(width, 600)
		frame.Parent = gui
		return frame
	end

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1
	end

	it("lays out its children in a grid that fills the width", function()
		local a, b = Instance.new("Frame"), Instance.new("Frame")
		local grid = Grid.new({ app = app, Parent = gui, children = { a, b } })
		local root = grid.Instance
		expect(a.Parent).to.equal(root)
		expect(b.Parent).to.equal(root)
		expect(grid.layout:IsA("UIGridLayout")).to.equal(true)
		expect(grid.layout.Parent).to.equal(root)
		expect(root.Size).to.equal(UDim2.fromScale(1, 0))
		expect(root.AutomaticSize).to.equal(Enum.AutomaticSize.Y)
		expect(a.LayoutOrder < b.LayoutOrder).to.equal(true)
	end)

	it("uses a fixed cell size", function()
		local grid = Grid.new({ app = app, Parent = gui, cellSize = UDim2.fromOffset(80, 120) })
		expect(grid.layout.CellSize).to.equal(UDim2.fromOffset(80, 120))
	end)

	it("spaces cells by the gap", function()
		local grid = Grid.new({ app = app, Parent = gui, gap = "Space2" })
		expect(grid.layout.CellPadding).to.equal(UDim2.fromOffset(8, 8))
		local pixels = Grid.new({ app = app, Parent = gui, gap = 5 })
		expect(pixels.layout.CellPadding).to.equal(UDim2.fromOffset(5, 5))
	end)

	it("shares the width between a number of columns", function()
		local grid = Grid.new({ app = app, Parent = box(400), columns = 4, gap = 8, cellHeight = 50 })
		Harness.flush()
		local cell = grid.layout.AbsoluteCellSize
		expect(near(cell.X, (400 - 3 * 8) / 4)).to.equal(true)
		expect(near(cell.Y, 50)).to.equal(true)
	end)

	it("keeps square cells unless given a height or an aspect ratio", function()
		local square = Grid.new({ app = app, Parent = box(400), columns = 4 })
		local wide = Grid.new({ app = app, Parent = box(400), columns = 2, gap = 10, aspectRatio = 2 })
		Harness.flush()
		expect(near(square.layout.AbsoluteCellSize.X, 100)).to.equal(true)
		expect(near(square.layout.AbsoluteCellSize.Y, 100)).to.equal(true)
		expect(near(wide.layout.AbsoluteCellSize.X, 195)).to.equal(true)
		expect(near(wide.layout.AbsoluteCellSize.Y, 97.5)).to.equal(true)
	end)

	it("follows a responsive column count", function()
		local grid = Grid.new({
			app = app,
			Parent = box(400),
			columns = { gamepad = 2, default = 4 },
			cellHeight = 40,
		})
		Harness.flush()
		expect(near(grid.layout.AbsoluteCellSize.X, 100)).to.equal(true)
		app.input:setMode("gamepad")
		Harness.flush()
		expect(near(grid.layout.AbsoluteCellSize.X, 200)).to.equal(true)
	end)

	it("fits as many columns as the minimum cell width allows", function()
		local frame = box(400)
		local grid = Grid.new({ app = app, Parent = frame, minCellWidth = 120, gap = 10, cellHeight = 40 })
		Harness.flush()
		-- (400 + 10) / (120 + 10) fits 3 columns
		expect(near(grid.layout.AbsoluteCellSize.X, (400 - 20) / 3)).to.equal(true)
		frame.Size = UDim2.fromOffset(250, 600)
		Harness.flush()
		-- 260 / 130 fits 2
		expect(near(grid.layout.AbsoluteCellSize.X, (250 - 10) / 2)).to.equal(true)
	end)

	it("keeps its columns inside its padding", function()
		local grid =
			Grid.new({ app = app, Parent = box(400), columns = 2, gap = 10, padding = 20, cellHeight = 40 })
		Harness.flush()
		expect(near(grid.layout.AbsoluteCellSize.X, (400 - 40 - 10) / 2)).to.equal(true)
	end)

	it("follows a reactive visible", function()
		local visible = Reactive.ref(true)
		local grid = Grid.new({ app = app, Parent = gui, visible = visible })
		visible(false)
		expect(grid.Instance.Visible).to.equal(false)
	end)
end
