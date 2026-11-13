return function()
	local Sheet = require(script.Parent.Sheet)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
	end)
	afterEach(function()
		cleanup()
	end)

	local function button(name: string): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.fromOffset(120, 32)
		return b
	end

	it("mounts closed into the modal portal and opens from methods and state", function()
		local sheet = Sheet.new({ app = app, id = "settings", title = "Settings" })
		expect(sheet.Instance.Parent).to.equal(app:portal("modal"))
		expect(sheet.Instance.Visible).to.equal(false)
		expect(sheet.titleLabel.Text).to.equal("Settings")
		sheet:open()
		expect(sheet.Instance.Visible).to.equal(true)
		app.state:set("ui.settings.open", false)
		expect(sheet.Instance.Visible).to.equal(false)
		sheet:toggle()
		expect(sheet:get("open")).to.equal(true)
	end)

	it("keeps open in step with a ref", function()
		local open = Reactive.ref(false)
		local sheet = Sheet.new({ app = app, open = open })
		open(true)
		expect(sheet.Instance.Visible).to.equal(true)
		sheet:close()
		expect(open()).to.equal(false)
	end)

	it("is a side panel on mouse, on the right unless told otherwise", function()
		local right = Sheet.new({ app = app, open = true })
		expect(right.presentation()).to.equal("panel")
		expect(right.frame.AnchorPoint).to.equal(Vector2.new(1, 0))
		expect(right.frame.Size.Y.Scale).to.equal(1)
		local left = Sheet.new({ app = app, open = true, side = "left", width = 300 })
		task.wait(0.2)
		expect(left.frame.AnchorPoint).to.equal(Vector2.new(0, 0))
		expect(left.frame.Size.X.Offset).to.equal(300)
	end)

	it("fills a panel to its footer, with no gap, however long the body is", function()
		local function rows(count: number): { Frame }
			local list = {}
			for i = 1, count do
				local row = Instance.new("Frame")
				row.Name = `Row{i}`
				row.Size = UDim2.new(1, 0, 0, 40)
				list[i] = row
			end
			return list
		end
		for _, count in { 2, 60 } do
			local sheet = Sheet.new({
				app = app,
				open = true,
				children = rows(count),
				footer = { button("Clear") },
			})
			task.wait(0.2)
			local body, footer = sheet.body.Instance, sheet.footer
			local inner = footer.Parent :: Frame
			-- The panel stays on the screen, however long its body
			local root = sheet.content:FindFirstAncestorWhichIsA("LayerCollector") :: ScreenGui
			local screenBottom = root.AbsolutePosition.Y + root.AbsoluteSize.Y
			expect(sheet.content.AbsolutePosition.Y + sheet.content.AbsoluteSize.Y <= screenBottom + 1).to.equal(
				true
			)
			-- The footer at the bottom of the panel (inside its padding)
			local bottom = inner.AbsolutePosition.Y + inner.AbsoluteSize.Y
			local footerBottom = footer.AbsolutePosition.Y + footer.AbsoluteSize.Y
			expect(bottom - footerBottom < 40).to.equal(true)
			expect(footerBottom <= bottom + 1).to.equal(true)
			-- The body runs to the footer: only the layout's gap between them
			local between = footer.AbsolutePosition.Y - (body.AbsolutePosition.Y + body.AbsoluteSize.Y)
			expect(between < 24).to.equal(true)
			sheet:destroy()
		end
	end)

	it("is a bottom drawer on touch", function()
		app.input:setMode("touch")
		local sheet = Sheet.new({ app = app, open = true })
		expect(sheet.presentation()).to.equal("drawer")
		expect(sheet.frame.AnchorPoint).to.equal(Vector2.new(0, 1))
		expect(sheet.frame.Size.X.Scale).to.equal(1)
		expect(sheet.handleBar.Visible).to.equal(true)
	end)

	it("puts children in a scrolling body and shows actions in a footer", function()
		local clicked = 0
		local sheet = Sheet.new({
			app = app,
			open = true,
			children = { button("Row") },
			actions = {
				{ text = "Cancel", variant = "outline" },
				{
					text = "Save",
					onClick = function()
						clicked += 1
					end,
				},
			},
		})
		expect(sheet.body.frame:IsA("ScrollingFrame")).to.equal(true)
		expect(sheet.body.content:FindFirstChild("Row")).to.be.ok()
		expect(sheet.footer.Visible).to.equal(true)
		sheet.actions[2]:click()
		expect(clicked).to.equal(1)
		expect(sheet:get("open")).to.equal(false)
	end)

	it("stacks several children in the body, one under the other", function()
		local first, second = button("First"), button("Second")
		local sheet = Sheet.new({ app = app, open = true, children = { first, second } })
		local layout = sheet.body.content:FindFirstChildOfClass("UIListLayout")
		expect(layout).to.be.ok()
		expect((layout :: UIListLayout).FillDirection).to.equal(Enum.FillDirection.Vertical)
		expect(first.LayoutOrder < second.LayoutOrder).to.equal(true)
	end)

	it("puts header and footer children outside the scrolling body", function()
		local filters, picked, row = button("Filters"), button("Picked"), button("Row")
		local sheet = Sheet.new({
			app = app,
			open = true,
			title = "Dances",
			header = { filters },
			children = { row },
			footer = { picked },
			actions = { { text = "Done" } },
		})
		expect(filters.Parent).to.equal(sheet.headerSlot)
		expect(picked.Parent).to.equal(sheet.footerSlot)
		expect(row:IsDescendantOf(sheet.body.frame)).to.equal(true)
		expect(filters:IsDescendantOf(sheet.body.frame)).to.equal(false)
		expect(picked:IsDescendantOf(sheet.body.frame)).to.equal(false)
		task.wait(0.2)
		-- Header under the title, body next, footer slot above the actions.
		expect(filters.AbsolutePosition.Y > sheet.titleLabel.AbsolutePosition.Y).to.equal(true)
		expect(sheet.body.frame.AbsolutePosition.Y >= filters.AbsolutePosition.Y + filters.AbsoluteSize.Y).to.equal(
			true
		)
		expect(picked.AbsolutePosition.Y < sheet.actions[1].Instance.AbsolutePosition.Y).to.equal(true)
	end)

	it("shows a footer slot with no actions", function()
		local sheet = Sheet.new({ app = app, open = true, footer = { button("Picked") } })
		expect(sheet.footer.Visible).to.equal(true)
		expect(sheet.actionsRow.Visible).to.equal(false)
		expect(sheet.headerSlot.Visible).to.equal(false)
	end)

	it("hides the footer with no actions", function()
		local sheet = Sheet.new({ app = app, open = true })
		expect(sheet.footer.Visible).to.equal(false)
	end)

	it("closes on back when dismissible and holds it when not", function()
		local sheet = Sheet.new({ app = app, open = true })
		expect(app.input:back()).to.equal(true)
		expect(sheet:get("open")).to.equal(false)
		local fixed = Sheet.new({ app = app, open = true, dismissible = false })
		expect(app.input:back()).to.equal(true)
		expect(fixed:get("open")).to.equal(true)
		expect(fixed.closeButton).to.equal(nil)
	end)

	it("can leave the rest of the screen working", function()
		local sheet = Sheet.new({ app = app, open = true, modal = false })
		local top = app.input:topScope()
		expect(top == nil or top.root ~= sheet.content).to.equal(true)
		expect(sheet.overlay.Active).to.equal(false)
		expect(app.state:get("overlay.modal")).to.equal(0)
		expect(app.state:get("overlay.count")).to.equal(1)
	end)

	it("dims behind it unless scrim is false", function()
		local dim = Sheet.new({ app = app, open = true })
		expect(dim.overlay:HasTag("ui-overlay-scrim")).to.equal(true)
		local bare = Sheet.new({ app = app, open = true, scrim = false })
		expect(bare.overlay:HasTag("ui-overlay-scrim")).to.equal(false)
	end)

	it("selects the first thing in the body on gamepad", function()
		app.input:setMode("gamepad")
		local row = button("Row")
		local sheet = Sheet.new({ app = app, children = { row } })
		sheet:open()
		expect(app.input:focused()).to.equal(row)
	end)

	it("takes defaultFocus, called with the sheet", function()
		app.input:setMode("gamepad")
		local first, second = button("First"), button("Second")
		local seen = nil
		local sheet = Sheet.new({
			app = app,
			children = { first, second },
			defaultFocus = function(s)
				seen = s
				return second
			end,
		})
		sheet:open()
		expect(seen).to.equal(sheet)
		expect(app.input:focused()).to.equal(second)
	end)

	it("takes focus without trapping it when non modal and given defaultFocus", function()
		app.input:setMode("gamepad")
		local row = button("Row")
		local sheet = Sheet.new({
			app = app,
			modal = false,
			children = { row },
			defaultFocus = function()
				return row
			end,
		})
		sheet:open()
		expect(app.input:focused()).to.equal(row)
		expect(app.state:get("overlay.modal")).to.equal(0)
		expect(sheet.content.SelectionGroup).to.equal(false)
	end)

	it("reports open changes and emits open and close", function()
		local changes = {}
		local sheet = Sheet.new({
			app = app,
			onOpenChange = function(open)
				table.insert(changes, open)
			end,
		})
		sheet:open()
		sheet:close()
		expect(#changes).to.equal(2)
		expect(changes[1]).to.equal(true)
		expect(changes[2]).to.equal(false)
	end)

	it("puts the close button in the top right corner, panel and drawer", function()
		local sheet = Sheet.new({ app = app, open = true, title = "Hi" })
		task.wait(0.2)
		local close = sheet.closeButton.Instance
		expect(close.Parent).to.equal(sheet.content)
		local c = sheet.content
		local right = c.AbsolutePosition.X + c.AbsoluteSize.X
		local gapRight = right - (close.AbsolutePosition.X + close.AbsoluteSize.X)
		local gapTop = close.AbsolutePosition.Y - c.AbsolutePosition.Y
		expect(gapRight >= 0 and gapRight <= 12).to.equal(true)
		expect(gapTop >= 0 and gapTop <= 12).to.equal(true)
		sheet:close()
		app.input:setMode("touch")
		sheet:open()
		task.wait(0.2)
		close = sheet.closeButton.Instance
		expect(close.Parent).to.equal(sheet.content)
		c = sheet.content
		right = c.AbsolutePosition.X + c.AbsoluteSize.X
		gapRight = right - (close.AbsolutePosition.X + close.AbsoluteSize.X)
		gapTop = close.AbsolutePosition.Y - c.AbsolutePosition.Y
		expect(gapRight >= 0 and gapRight <= 12).to.equal(true)
		expect(gapTop >= 0 and gapTop <= 12).to.equal(true)
	end)

	it("caps the body so a long one scrolls inside the sheet", function()
		app.input:setMode("touch")
		local rows = {}
		for i = 1, 40 do
			table.insert(rows, button("Row" .. i))
		end
		local list = Instance.new("UIListLayout")
		table.insert(rows, list)
		local sheet = Sheet.new({ app = app, open = true, title = "Long", children = rows })
		task.wait(0.3)
		local content = sheet.content
		local root = sheet.Instance
		expect(content.AbsoluteSize.Y <= root.AbsoluteSize.Y * 0.86).to.equal(true)
		expect(sheet.body.frame.AbsoluteCanvasSize.Y > sheet.body.frame.AbsoluteSize.Y).to.equal(true)
	end)

	it("gives bodyRoom, the height a long body is capped at", function()
		local Scroll = require(script.Parent.Parent.Core.Scroll)
		local rows: { Instance } = {}
		for i = 1, 40 do
			table.insert(rows, button("Row" .. i))
		end
		table.insert(rows, Instance.new("UIListLayout"))
		local sheet = Sheet.new({ app = app, open = true, title = "Long", children = rows })
		task.wait(0.3)
		local room = sheet.bodyRoom()
		expect(room > 0 and room < math.huge).to.equal(true)
		local height = sheet.body.Instance.AbsoluteSize.Y / Scroll.scaleOf(sheet.content)
		expect(math.abs(height - room) <= 2).to.equal(true)
	end)

	it("leaves room for the bottom safe area as a drawer", function()
		local Overlay = require(script.Parent.Parent.Core.Overlay)
		local measure = Overlay.measureSafeBottom
		Overlay.measureSafeBottom = function()
			return 34
		end
		app.input:setMode("touch")
		local ok, err = pcall(function()
			local sheet = Sheet.new({ app = app, title = "Bag", open = true })
			local safe = sheet.content:FindFirstChild("SafeArea", true) :: Frame
			expect(safe ~= nil).to.equal(true)
			expect(safe.Visible).to.equal(true)
			expect(safe.Size.Y.Offset).to.equal(34)
		end)
		Overlay.measureSafeBottom = measure
		assert(ok, err)
	end)
	describe("the frame (ADR 0047)", function()
		local Tokens = require(script.Parent.Parent.Core.Tokens)

		local function framed(primitives: { [string]: any })
			local all = table.clone(Tokens.primitives)
			for k, v in primitives do
				all[k] = v
			end
			cleanup()
			app, cleanup = Harness.app({ theme = "light", primitives = all })
		end

		it("puts the panel in a frame the overlay places, the panel as it was", function()
			local panel = Sheet.new({ app = app, title = "Hi" })
			panel:open()
			expect(panel.frame).to.be.ok()
			expect(panel.content.Parent).to.equal(panel.frame)
			expect(panel.content:HasTag("ui-sheet-content")).to.equal(true)
			expect(panel.titleLabel.Text).to.equal("Hi")
		end)

		it("has no shadow and the title inside unless the theme asks", function()
			local panel = Sheet.new({ app = app, title = "Hi" })
			panel:open()
			expect(panel.shadow.Visible).to.equal(false)
			expect(panel.plate).to.equal(nil)
			expect(panel.titleLabel:IsDescendantOf(panel.content)).to.equal(true)
		end)

		it("draws the shadow the PanelShadow token's pixels right and down, behind the panel", function()
			framed({ PanelShadow = 6 })
			local panel = Sheet.new({ app = app, title = "Hi" })
			panel:open()
			task.wait()
			expect(panel.shadow.Visible).to.equal(true)
			expect(panel.shadow:HasTag("ui-sheet-shadow")).to.equal(true)
			expect(panel.shadow.Parent).to.equal(panel.frame)
			expect(panel.shadow.ZIndex < panel.content.ZIndex).to.equal(true)
			local moved = panel.shadow.AbsolutePosition - panel.content.AbsolutePosition
			local scale = panel.content.AbsoluteSize.X / math.max(1, panel.shadow.AbsoluteSize.X)
			expect(math.abs(scale - 1) < 0.01).to.equal(true)
			expect(moved.X > 0 and moved.Y > 0 and math.abs(moved.X - moved.Y) < 0.5).to.equal(true)
		end)

		it("puts the title on a plate on the top edge, with titlePlacement edge", function()
			local panel = Sheet.new({
				app = app,
				title = "Club Pass",
				description = "Season one",
				titlePlacement = "edge",
			})
			panel:open()
			-- The plate is measured once drawn, and the panel moves down for it a frame later (a few more
			-- under a busy run)
			for _ = 1, 30 do
				task.wait()
				if panel.plate and panel.plate.AbsolutePosition.Y < panel.content.AbsolutePosition.Y then
					break
				end
			end
			expect(panel.plate).to.be.ok()
			expect(panel.plate:HasTag("ui-sheet-plate")).to.equal(true)
			expect(panel.titleLabel:IsDescendantOf(panel.plate)).to.equal(true)
			expect(panel.titleLabel.Text).to.equal("Club Pass")
			expect(panel.titleLabel:HasTag("ui-sheet-title")).to.equal(true)
			expect(panel.descriptionLabel:IsDescendantOf(panel.content)).to.equal(true)
			-- Standing on the edge: its top above the panel's, its bottom over it
			local plateTop = panel.plate.AbsolutePosition.Y
			local plateBottom = plateTop + panel.plate.AbsoluteSize.Y
			local panelTop = panel.content.AbsolutePosition.Y
			expect(plateTop < panelTop).to.equal(true)
			expect(plateBottom > panelTop).to.equal(true)
		end)

		it("leaves out the heading's row with the title on the edge and no description", function()
			local bare = Sheet.new({ app = app, title = "Hi", titlePlacement = "edge" })
			bare:open()
			local heading = bare.descriptionLabel.Parent :: GuiObject
			expect(heading.Visible).to.equal(false)
			local described =
				Sheet.new({ app = app, title = "Hi", description = "More", titlePlacement = "edge" })
			described:open()
			expect((described.descriptionLabel.Parent :: GuiObject).Visible).to.equal(true)
		end)

		it("starts its content clear of an edge title's plate", function()
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 20)
			local panel = Sheet.new({ app = app, title = "Hi", titlePlacement = "edge", header = { row } })
			panel:open()
			for _ = 1, 30 do
				task.wait()
				if panel.plate and panel.plate.AbsolutePosition.Y < panel.content.AbsolutePosition.Y then
					break
				end
			end
			task.wait()
			-- The plate comes down over the panel: the first row starts the panel's own padding (at
			-- least the small one) under the plate, not under the panel's top edge
			local plateBottom = panel.plate.AbsolutePosition.Y + panel.plate.AbsoluteSize.Y
			expect(row.AbsolutePosition.Y - plateBottom >= 12).to.equal(true)
		end)

		it("keeps the header slot clear of the close button when it is the top row", function()
			local function slotted(props: { [string]: any })
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 20)
				props.app = app
				props.title = "Hi"
				props.titlePlacement = "edge"
				props.header = { row }
				local panel = Sheet.new(props)
				panel:open()
				for _ = 1, 3 do
					task.wait()
				end
				return row, panel.closeButton.Instance
			end
			-- No row over it: the slot stops short of the close button
			local row, close = slotted({})
			expect(row.AbsolutePosition.X + row.AbsoluteSize.X <= close.AbsolutePosition.X).to.equal(true)
			-- With the description's row over it, the slot keeps its full width
			local under, closeOver = slotted({ description = "More" })
			expect(under.AbsolutePosition.X + under.AbsoluteSize.X > closeOver.AbsolutePosition.X).to.equal(
				true
			)
		end)

		it("gives the shadow its panel's own corners, square or round", function()
			framed({ PanelShadow = 6 })
			local panel = Sheet.new({ app = app, title = "Hi", presentation = "panel" })
			panel:open()
			task.wait()
			local corner = panel.content:FindFirstChildWhichIsA("UICorner")
			local shadowCorner = panel.shadow:FindFirstChildWhichIsA("UICorner")
			local want = if corner then corner.CornerRadius else UDim.new(0, 0)
			local got = if shadowCorner then shadowCorner.CornerRadius else UDim.new(0, 0)
			expect(got).to.equal(want)
		end)

		it("takes the PanelTitleEdge token as every panel's default", function()
			framed({ PanelTitleEdge = 1 })
			local panel = Sheet.new({ app = app, title = "Hi" })
			panel:open()
			expect(panel.plate).to.be.ok()
			local inside = Sheet.new({ app = app, title = "Hi", titlePlacement = "inside" })
			inside:open()
			expect(inside.plate).to.equal(nil)
		end)
	end)
end
