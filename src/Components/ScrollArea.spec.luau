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

	it("keeps its content clear of the scrollbar once it scrolls", function()
		local child = block(60)
		local area = ScrollArea.new({
			app = app,
			Parent = gui,
			size = UDim2.fromOffset(200, 0),
			maxHeight = 100,
			padding = 4,
			children = { child },
		})
		Harness.flush()
		local frame = area.Instance
		expect(math.abs(area.content.AbsoluteSize.X - frame.AbsoluteSize.X) < 1).to.equal(true)
		child.Size = UDim2.new(1, 0, 0, 400)
		Harness.flush()
		expect(frame.AbsoluteWindowSize.X < frame.AbsoluteSize.X).to.equal(true)
		expect(area.content.AbsoluteSize.X <= frame.AbsoluteWindowSize.X + 0.5).to.equal(true)
		child.Size = UDim2.new(1, 0, 0, 40)
		Harness.flush()
		expect(math.abs(area.content.AbsoluteSize.X - frame.AbsoluteSize.X) < 1).to.equal(true)
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

	describe("gamepad", function()
		local function text(height: number): TextLabel
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 0, height)
			return label
		end
		local function make(children)
			local area = ScrollArea.new({
				app = app,
				Parent = gui,
				size = UDim2.fromOffset(200, 100),
				children = children,
			})
			task.wait(0.1)
			return area
		end

		it("lets selection pass to the controls inside it", function()
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(1, 0, 0, 400)
			local area = make({ button })
			expect(area.Instance.Selectable).to.equal(false)
		end)

		it("can be selected itself when it scrolls and holds nothing selectable", function()
			local area = make({ text(400) })
			expect(area.Instance.Selectable).to.equal(true)
		end)

		it("is not selectable with nothing to scroll", function()
			local area = make({ text(40) })
			expect(area.Instance.Selectable).to.equal(false)
		end)

		it("follows controls added and removed later", function()
			local area = make({ text(400) })
			local button = Instance.new("TextButton")
			button.Parent = area.content
			task.wait(0.1)
			expect(area.Instance.Selectable).to.equal(false)
			button:Destroy()
			task.wait(0.1)
			expect(area.Instance.Selectable).to.equal(true)
		end)
	end)
	describe("scrollbar", function()
		-- A 200 x 100 area; `height` of content inside it.
		local function area(height: number, props: { [string]: any }?)
			local p = table.clone(props or {})
			p.app = app
			p.Parent = gui
			p.size = UDim2.fromOffset(200, 100)
			p.children = { block(height) }
			local handle = ScrollArea.new(p)
			task.wait(0.1)
			return handle
		end
		local function shown(handle): boolean
			return handle.Instance:HasTag("ui-scroll-bar-visible")
		end

		it("rejects an unknown mode", function()
			expect(function()
				ScrollArea.new({ app = app, scrollbar = "sometimes" })
			end).to.throw()
		end)

		it("auto shows only while content overflows, not when it fits exactly", function()
			expect(shown(area(400, { scrollbar = "auto" }))).to.equal(true)
			expect(shown(area(100, { scrollbar = "auto" }))).to.equal(false)
			expect(shown(area(40, { scrollbar = "auto" }))).to.equal(false)
		end)

		it("always shows", function()
			expect(shown(area(40, { scrollbar = "always" }))).to.equal(true)
		end)

		it("scroll shows while scrolling, then hides after the delay", function()
			local handle = area(400, { scrollbar = "scroll", hideDelay = 0.2 })
			expect(shown(handle)).to.equal(false)
			handle.Instance.CanvasPosition = Vector2.new(0, 50)
			task.wait(0.05)
			expect(shown(handle)).to.equal(true)
			task.wait(0.3)
			expect(shown(handle)).to.equal(false)
		end)

		it("scroll stays hidden when nothing overflows", function()
			local handle = area(40, { scrollbar = "scroll" })
			handle.Instance.CanvasPosition = Vector2.new(0, 10)
			task.wait(0.05)
			expect(shown(handle)).to.equal(false)
		end)

		it("hover is the default and shows while the mouse is over it", function()
			local handle = area(400)
			expect(handle.scrollbar).to.equal("hover")
			expect(shown(handle)).to.equal(false)
			handle._pointer(true)
			expect(shown(handle)).to.equal(true)
			handle._pointer(false)
			expect(shown(handle)).to.equal(false)
		end)

		it("hover acts like scroll on touch", function()
			local handle = area(400)
			app.input:setMode("touch")
			handle._pointer(true)
			expect(shown(handle)).to.equal(false)
		end)

		it("glimpse shows briefly when the mouse enters", function()
			local handle = area(400, { scrollbar = "glimpse", hideDelay = 0.2 })
			expect(shown(handle)).to.equal(false)
			handle._pointer(true)
			expect(shown(handle)).to.equal(true)
			task.wait(0.3)
			expect(shown(handle)).to.equal(false)
		end)

		it("styles the bar from the tag", function()
			local handle = area(400, { scrollbar = "auto" })
			Harness.flush()
			expect(Harness.styled(handle.Instance, "ScrollBarImageTransparency")).to.equal(0)
			local hidden = area(400, { scrollbar = "scroll" })
			Harness.flush()
			expect(Harness.styled(hidden.Instance, "ScrollBarImageTransparency")).to.equal(1)
		end)
	end)
end
