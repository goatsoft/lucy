return function()
	local Grid = require(script.Parent.Grid)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Scroll = require(script.Parent.Parent.Core.Scroll)

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

	it("keeps every column on its row when the gap is not a whole pixel", function()
		-- CellPadding rounds to whole pixels, so the cells must be sized with the
		-- same rounded gap or the last column wraps.
		local grid = Grid.new({ app = app, Parent = box(560), columns = 3, cellHeight = 40, gap = 7.5 })
		local pad = grid.layout.CellPadding.X.Offset
		local cell = grid.layout.CellSize.X
		expect(cell.Scale).to.be.near(1 / 3, 1e-6)
		expect(cell.Offset * 3 + pad * 2 <= 0).to.equal(true)
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
		if not Harness.laysOutLive() then
			return -- the columns follow the measured width: live layout only (Harness.laysOutLive)
		end
		local frame = box(400)
		local grid = Grid.new({ app = app, Parent = frame, minCellWidth = 120, gap = 10, cellHeight = 40 })
		Harness.flush()
		-- (400 + 10) / (120 + 10) fits 3 columns
		expect(grid.layout.CellSize.X.Scale).to.be.near(1 / 3, 1e-6)
		expect(near(grid.layout.AbsoluteCellSize.X, (400 - 20) / 3)).to.equal(true)
		frame.Size = UDim2.fromOffset(250, 600)
		Harness.flush()
		-- 260 / 130 fits 2
		expect(grid.layout.CellSize.X.Scale).to.be.near(1 / 2, 1e-6)
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

	describe("virtual", function()
		local ScrollArea = require(script.Parent.ScrollArea)

		local function numbers(n: number): { number }
			local out = {}
			for i = 1, n do
				out[i] = i
			end
			return out
		end

		-- A grid of numbered cells in a 400 by 300 scroll area.
		local function make(props: { [string]: any }): (any, ScrollingFrame)
			local area =
				ScrollArea.new({ app = app, Parent = gui, size = UDim2.fromOffset(400, 300), fade = false })
			props.app = app
			props.virtual = true
			props.item = props.item
				or function(n: number)
					local label = Instance.new("TextLabel")
					label.Name = `N{n}`
					label.Text = tostring(n)
					label.Size = UDim2.fromScale(1, 1)
					return label
				end
			local grid = Grid.new(props)
			grid.Instance.Parent = area.content
			Harness.flush()
			task.wait(0.1)
			return grid, area.frame :: ScrollingFrame
		end

		it("needs a cellHeight", function()
			expect(function()
				Grid.new({
					app = app,
					Parent = gui,
					virtual = true,
					columns = 4,
					items = numbers(10),
					item = function() end,
				})
			end).to.throw()
		end)

		it("builds only the cells near the view, in a frame as tall as all of them", function()
			local grid, scroller = make({ items = numbers(1000), columns = 4, cellHeight = 50, gap = 0 })
			-- 1000 cells in 4 columns are 250 rows of 50
			expect(near(grid.Instance.AbsoluteSize.Y / Scroll.scaleOf(grid.Instance), 250 * 50)).to.equal(
				true
			)
			expect(grid.cellCount() < 4 * 16).to.equal(true)
			expect(grid.cellFor(1)).to.be.ok()
			expect(grid.cellFor(500)).to.equal(nil)
			-- Scroll to row 100 (cells 397 to 400)
			local scale = Scroll.scaleOf(scroller)
			scroller.CanvasPosition = Vector2.new(0, 99 * 50 * scale)
			task.wait(0.2)
			expect(grid.cellFor(397)).to.be.ok()
			expect(grid.cellFor(1)).to.equal(nil)
			expect(grid.cellFor(397):FindFirstChild("N397", true)).to.be.ok()
		end)

		it("places each cell by its column and row", function()
			local grid = make({ items = numbers(20), columns = 4, cellHeight = 50, gap = 10 })
			local first, sixth = grid.cellFor(1), grid.cellFor(6)
			local scale = Scroll.scaleOf(grid.Instance)
			local origin = grid.Instance.AbsolutePosition
			local width = grid.Instance.AbsoluteSize.X / scale
			local cell = (width - 3 * 10) / 4
			expect(near(first.AbsoluteSize.X / scale, cell)).to.equal(true)
			expect(near(first.AbsoluteSize.Y / scale, 50)).to.equal(true)
			-- cell 6 is column 2, row 2
			expect(near((sixth.AbsolutePosition.X - origin.X) / scale, cell + 10)).to.equal(true)
			expect(near((sixth.AbsolutePosition.Y - origin.Y) / scale, 60)).to.equal(true)
			-- 20 cells are 5 rows: 5 * 50 + 4 * 10
			expect(near(grid.Instance.AbsoluteSize.Y / scale, 290)).to.equal(true)
		end)

		it("follows its items, keeping the cells it can by key", function()
			local items = Reactive.ref(numbers(8))
			local built = 0
			local grid = make({
				items = items,
				columns = 4,
				cellHeight = 50,
				item = function(n: number)
					built += 1
					local frame = Instance.new("Frame")
					frame.Name = `N{n}`
					return frame
				end,
				key = function(n: number)
					return n
				end,
			})
			expect(built).to.equal(8)
			local kept = grid.cellFor(5)
			items({ 5, 6, 7, 8, 9 })
			Harness.flush()
			task.wait(0.1)
			expect(built).to.equal(9)
			expect(grid.cellFor(5)).to.equal(kept)
			expect(grid.cellFor(1)).to.equal(nil)
			-- 5 is first now: column 1, row 1
			expect(near(kept.AbsolutePosition.X, grid.Instance.AbsolutePosition.X)).to.equal(true)
			expect(near(kept.AbsolutePosition.Y, grid.Instance.AbsolutePosition.Y)).to.equal(true)
		end)

		it("fits columns to minCellWidth", function()
			local grid = make({ items = numbers(12), minCellWidth = 120, gap = 10, cellHeight = 40 })
			local scale = Scroll.scaleOf(grid.Instance)
			local width = grid.Instance.AbsoluteSize.X / scale
			local n = Grid.fit(width, 120, 10)
			local second = grid.cellFor(2)
			expect(
				near(
					(second.AbsolutePosition.X - grid.Instance.AbsolutePosition.X) / scale,
					(width - 10 * (n - 1)) / n + 10
				)
			).to.equal(true)
		end)

		it("follows a responsive cell height, moving its cells", function()
			local grid = make({
				items = numbers(8),
				columns = 4,
				cellHeight = { gamepad = 80, default = 50 },
				gap = 0,
			})
			local scale = Scroll.scaleOf(grid.Instance)
			-- 8 cells in 4 columns are 2 rows
			expect(near(grid.Instance.AbsoluteSize.Y / scale, 100)).to.equal(true)
			app.input:setMode("gamepad")
			Harness.flush()
			task.wait(0.1)
			expect(near(grid.Instance.AbsoluteSize.Y / scale, 160)).to.equal(true)
			local fifth = grid.cellFor(5)
			expect(near(fifth.AbsoluteSize.Y / scale, 80)).to.equal(true)
			expect(near((fifth.AbsolutePosition.Y - grid.Instance.AbsolutePosition.Y) / scale, 80)).to.equal(
				true
			)
		end)
	end)
end
