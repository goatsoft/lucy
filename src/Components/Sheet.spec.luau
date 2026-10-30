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
		expect(right.content.AnchorPoint).to.equal(Vector2.new(1, 0))
		expect(right.content.Size.Y.Scale).to.equal(1)
		local left = Sheet.new({ app = app, open = true, side = "left", width = 300 })
		task.wait(0.2)
		expect(left.content.AnchorPoint).to.equal(Vector2.new(0, 0))
		expect(left.content.Size.X.Offset).to.equal(300)
	end)

	it("is a bottom drawer on touch", function()
		app.input:setMode("touch")
		local sheet = Sheet.new({ app = app, open = true })
		expect(sheet.presentation()).to.equal("drawer")
		expect(sheet.content.AnchorPoint).to.equal(Vector2.new(0, 1))
		expect(sheet.content.Size.X.Scale).to.equal(1)
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
		expect(sheet.body.Instance:IsA("ScrollingFrame")).to.equal(true)
		expect(sheet.body.content:FindFirstChild("Row")).to.be.ok()
		expect(sheet.footer.Visible).to.equal(true)
		sheet.actions[2]:click()
		expect(clicked).to.equal(1)
		expect(sheet:get("open")).to.equal(false)
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
		expect(sheet.body.Instance.AbsoluteCanvasSize.Y > sheet.body.Instance.AbsoluteSize.Y).to.equal(true)
	end)
end
