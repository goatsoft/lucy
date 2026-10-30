return function()
	local Table = require(script.Parent.Table)
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

	local COLUMNS = {
		{ key = "rank", header = "#", width = 48 },
		{ key = "name", header = "Player", width = { fill = 2 } },
		{
			id = "score",
			header = "Score",
			width = { fill = 1 },
			align = "right",
			get = function(row)
				return row.score
			end,
		},
	}
	local function players(count: number, offset: number?)
		local out = {}
		for i = 1, count do
			table.insert(out, { userId = i, rank = i, name = "P" .. i, score = (offset or 0) + i * 10 })
		end
		return out
	end
	local function make(props: { [string]: any })
		local p = table.clone(props)
		p.app = app
		p.Parent = gui
		p.columns = p.columns or COLUMNS
		p.rowId = p.rowId or function(row)
			return row.userId
		end
		p.size = p.size or UDim2.fromOffset(400, 0)
		return Table.new(p)
	end
	local function cellText(t, rowId: any, columnId: string): string
		local row = t.rowFor(rowId)
		local cell = row and row:FindFirstChild(columnId, true)
		local label = cell
			and (if cell:IsA("TextLabel") then cell else cell:FindFirstChildWhichIsA("TextLabel", true))
		return if label then label.Text else "<none>"
	end

	it("draws a header and a row per item, with values from key or get", function()
		local t = make({ rows = players(3) })
		expect(t.header:FindFirstChild("name", true)).to.be.ok()
		expect(t.rowCount()).to.equal(3)
		expect(cellText(t, 2, "name")).to.equal("P2")
		expect(cellText(t, 2, "score")).to.equal("20")
	end)

	it("sizes columns in pixels and fill shares", function()
		local t = make({ rows = players(1) })
		task.wait(0.2)
		local row = t.rowFor(1)
		local rank = row:FindFirstChild("rank", true) :: GuiObject
		local name = row:FindFirstChild("name", true) :: GuiObject
		local score = row:FindFirstChild("score", true) :: GuiObject
		local scale = rank.AbsoluteSize.X / 48
		expect(math.abs(name.AbsoluteSize.X / score.AbsoluteSize.X - 2) < 0.05).to.equal(true)
		expect(math.abs((rank.AbsoluteSize.X + name.AbsoluteSize.X + score.AbsoluteSize.X) / scale - 400) < 2).to.equal(
			true
		)
	end)

	it("updates cells in place when the data changes, keeping rows by id", function()
		local data = Reactive.ref(players(3))
		local t = make({ rows = data })
		local before = t.rowFor(2)
		data(players(3, 1000))
		expect(cellText(t, 2, "score")).to.equal("1020")
		expect(t.rowFor(2)).to.equal(before)
		local reordered = players(3)
		reordered[1], reordered[3] = reordered[3], reordered[1]
		data(reordered)
		expect(t.rowFor(2)).to.equal(before)
		expect(t.rowFor(3).LayoutOrder < t.rowFor(1).LayoutOrder).to.equal(true)
	end)

	it("renders custom cells with getters for the row and value", function()
		local columns = {
			{ key = "name", header = "Player" },
			{
				key = "score",
				header = "Score",
				cell = function(ctx)
					local label = Instance.new("TextLabel")
					label.Name = "Custom"
					label.Text = tostring(ctx.value()) .. " pts"
					return label
				end,
			},
		}
		local t = make({ columns = columns, rows = players(2) })
		local custom = t.rowFor(1):FindFirstChild("Custom", true)
		expect(custom).to.be.ok()
		expect((custom :: TextLabel).Text).to.equal("10 pts")
	end)

	it("marks the highlighted row and stripes every other row", function()
		local t = make({
			rows = players(4),
			striped = true,
			highlight = function(row)
				return row.userId == 3
			end,
		})
		expect(t.rowFor(3):HasTag("ui-table-row-highlight")).to.equal(true)
		expect(t.rowFor(1):HasTag("ui-table-row-highlight")).to.equal(false)
		expect(t.rowFor(2):HasTag("ui-table-row-striped")).to.equal(true)
		expect(t.rowFor(1):HasTag("ui-table-row-striped")).to.equal(false)
	end)

	it("makes rows pressable and selectable with onRowClick", function()
		local clicked = {}
		local t = make({
			rows = players(2),
			onRowClick = function(row)
				table.insert(clicked, row.userId)
			end,
		})
		local row = t.rowFor(2)
		expect(row:IsA("TextButton")).to.equal(true)
		expect(row.Selectable).to.equal(true)
		t.pressRow(2)
		expect(clicked[1]).to.equal(2)
		local plain = make({ rows = players(1) })
		expect(plain.rowFor(1):IsA("TextButton")).to.equal(false)
	end)

	it("shows the empty text with no rows", function()
		local data = Reactive.ref({})
		local t = make({ rows = data, empty = "No players yet" })
		expect(t.emptyLabel.Visible).to.equal(true)
		expect(t.emptyLabel.Text).to.equal("No players yet")
		data(players(1))
		expect(t.emptyLabel.Visible).to.equal(false)
	end)

	it("keeps the header out of the scrolling body, capped by maxHeight", function()
		local t = make({ rows = players(40), maxHeight = 200 })
		task.wait(0.3)
		expect(t.header:IsDescendantOf(t.body.Instance)).to.equal(false)
		local body = t.body.Instance
		expect(body.AbsoluteCanvasSize.Y > body.AbsoluteSize.Y).to.equal(true)
		-- The last header cell ends where the last body cell ends, scroll bar or not.
		local headCell = t.header:FindFirstChild("score", true) :: GuiObject
		local rowCell = t.rowFor(1):FindFirstChild("score", true) :: GuiObject
		local headRight = headCell.AbsolutePosition.X + headCell.AbsoluteSize.X
		local rowRight = rowCell.AbsolutePosition.X + rowCell.AbsoluteSize.X
		expect(math.abs(headRight - rowRight) <= 1).to.equal(true)
	end)

	describe("virtual", function()
		it("needs a rowHeight", function()
			expect(function()
				make({ rows = players(5), virtual = true, maxHeight = 100 })
			end).to.throw()
		end)

		it("builds only the rows near the view, for a canvas as tall as all of them", function()
			local t = make({ rows = players(1000), virtual = true, rowHeight = 30, maxHeight = 300 })
			task.wait(0.3)
			expect(t.rowCount() < 40).to.equal(true)
			expect(t.rowFor(1)).to.be.ok()
			expect(t.rowFor(500)).to.equal(nil)
			local body = t.body.Instance
			local scale = body.AbsoluteCanvasSize.Y / (1000 * 30)
			expect(math.abs(scale - body.AbsoluteSize.Y / 300) < 0.05).to.equal(true)
			-- CanvasPosition is in screen pixels, after the portal's UIScale.
			body.CanvasPosition = Vector2.new(0, 500 * 30 * scale)
			task.wait(0.2)
			expect(t.rowFor(505)).to.be.ok()
			expect(t.rowFor(1)).to.equal(nil)
			expect(cellText(t, 505, "name")).to.equal("P505")
		end)

		it("reports the end once per row count", function()
			local fired = 0
			local data = Reactive.ref(players(50))
			local t = make({
				rows = data,
				virtual = true,
				rowHeight = 30,
				maxHeight = 300,
				onEndReached = function()
					fired += 1
				end,
			})
			task.wait(0.2)
			expect(fired).to.equal(0)
			local body = t.body.Instance
			local scale = body.AbsoluteSize.Y / 300
			body.CanvasPosition = Vector2.new(0, 50 * 30 * scale)
			task.wait(0.2)
			expect(fired).to.equal(1)
			body.CanvasPosition = Vector2.new(0, 49 * 30 * scale)
			task.wait(0.2)
			expect(fired).to.equal(1)
			data(players(100))
			task.wait(0.1)
			body.CanvasPosition = Vector2.new(0, 100 * 30 * scale)
			task.wait(0.2)
			expect(fired).to.equal(2)
		end)
	end)
end
