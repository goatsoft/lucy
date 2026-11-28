return function()
	local Kept = require(script.Parent.Kept)
	local Sheet = require(script.Parent.Parent.Components.Sheet)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
	end)
	afterEach(function()
		cleanup()
	end)

	-- A health bar at the bottom middle of the screen, in a list beside another thing
	local function hud()
		local gui = Harness.mount(app)
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.Size = UDim2.new(1, 0, 0, 40)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0, 1)
		bar.BackgroundTransparency = 1
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = bar
		local health = Instance.new("Frame")
		health.Name = "Health"
		health.Size = UDim2.fromOffset(200, 40)
		health.LayoutOrder = 1
		health.Parent = bar
		local after = Instance.new("Frame")
		after.Name = "After"
		after.Size = UDim2.fromOffset(100, 40)
		after.LayoutOrder = 2
		after.Parent = bar
		bar.Parent = gui
		Harness.flush()
		return gui, health, after
	end

	it("lifts a kept frame over a modal overlay and puts it back after", function()
		local _gui, health, after = hud()
		local spot = health.AbsolutePosition
		local afterSpot = after.AbsolutePosition
		app:keep(health)
		local sheet = Sheet.new({ app = app, width = 300 })
		sheet:open()
		expect(Harness.waitFor(function()
			return health:FindFirstAncestorWhichIsA("ScreenGui") == app:portal("kept")
		end, 1)).to.equal(true)
		Harness.flush()
		-- in the same place, and what was beside it has not moved
		expect((health.AbsolutePosition - spot).Magnitude <= 2).to.equal(true)
		expect((after.AbsolutePosition - afterSpot).Magnitude <= 2).to.equal(true)
		expect(#Kept.zones(app)()).to.equal(1)
		sheet:close()
		expect(Harness.waitFor(function()
			return health.Parent ~= nil and health.Parent.Name == "Bar"
		end, 1)).to.equal(true)
		expect(#Kept.zones(app)()).to.equal(0)
	end)

	it("stops keeping a frame", function()
		local _gui, health = hud()
		local stop = app:keep(health)
		stop()
		local sheet = Sheet.new({ app = app, width = 300 })
		sheet:open()
		Harness.flush()
		expect(health.Parent and health.Parent.Name).to.equal("Bar")
	end)

	it("leaves room in a docked sheet over a kept frame at the bottom", function()
		local _gui, health = hud()
		app:keep(health)
		local sheet = Sheet.new({ app = app, dock = "loot", side = "left", width = 400 })
		sheet:open()
		expect(Harness.waitFor(function()
			return sheet.frame ~= nil and sheet.frame.AbsoluteSize.X > 0 and #Kept.zones(app)() == 1
		end, 1)).to.equal(true)
		expect(Harness.waitFor(function()
			local bottom = sheet.frame.AbsolutePosition.Y + sheet.frame.AbsoluteSize.Y
			return bottom <= health.AbsolutePosition.Y
		end, 1)).to.equal(true)
	end)
end
