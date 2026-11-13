return function()
	local PanelCorner = require(script.Parent.PanelCorner)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui, scope
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
		scope = Reactive.effectScope()
	end)
	afterEach(function()
		scope:stop()
		cleanup()
	end)

	-- A hand-built panel, 400 wide
	local function panel(): Frame
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(400, 200)
		frame.Parent = gui
		return frame
	end

	it("puts the close button in the panel's top right corner, as a dialog's", function()
		local content = panel()
		local closed = false
		local corner
		scope:run(function()
			corner = PanelCorner.new(app, content, {
				close = true,
				onClose = function()
					closed = true
				end,
			})
		end)
		Harness.flush()
		local close = corner.closeButton.Instance :: GuiObject
		expect(close:IsDescendantOf(content)).to.equal(true)
		local right = content.AbsolutePosition.X + content.AbsoluteSize.X
		expect(right - (close.AbsolutePosition.X + close.AbsoluteSize.X) <= 8).to.equal(true)
		expect(close.AbsolutePosition.Y - content.AbsolutePosition.Y <= 8).to.equal(true)
		expect(corner.room()).to.equal(PanelCorner.closeRoom)
		corner.closeButton:click()
		expect(closed).to.equal(true)
	end)

	it("stays at the top when the panel's content is padded down", function()
		local content = panel()
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 20)
		padding.Parent = content
		local corner
		scope:run(function()
			corner = PanelCorner.new(app, content, {
				close = true,
				clear = function()
					return 20
				end,
			})
		end)
		Harness.flush()
		local close = corner.closeButton.Instance :: GuiObject
		expect(close.AbsolutePosition.Y - content.AbsolutePosition.Y <= 8).to.equal(true)
	end)

	it("puts the slot's children left of the close button, and measures the room they take", function()
		local content = panel()
		local chip = Instance.new("Frame")
		chip.Size = UDim2.fromOffset(80, 20)
		local corner
		scope:run(function()
			corner = PanelCorner.new(app, content, { close = true, children = { chip } })
		end)
		Harness.flush()
		task.wait()
		local close = corner.closeButton.Instance :: GuiObject
		expect(chip.AbsolutePosition.X + chip.AbsoluteSize.X <= close.AbsolutePosition.X).to.equal(true)
		expect(corner.room() > PanelCorner.closeRoom).to.equal(true)
		local right = content.AbsolutePosition.X + content.AbsoluteSize.X
		expect(corner.room() >= right - chip.AbsolutePosition.X).to.equal(true)
	end)

	it("takes no room with no close button and nothing in the slot", function()
		local corner
		scope:run(function()
			corner = PanelCorner.new(app, panel(), {})
		end)
		expect(corner.closeButton).to.equal(nil)
		expect(corner.room()).to.equal(0)
	end)
end
