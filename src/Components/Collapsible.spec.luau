return function()
	local Collapsible = require(script.Parent.Collapsible)
	local Animate = require(script.Parent.Parent.Core.Animate)
	local Composables = require(script.Parent.Parent.Composables)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Scroll = require(script.Parent.Parent.Core.Scroll)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		Animate.manual = true
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
		Animate.manual = false
	end)

	local function settle(seconds: number)
		for _ = 1, math.ceil(seconds * 60) do
			Animate.step(1 / 60)
		end
	end

	local function box(height: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = "Box"
		frame.Size = UDim2.new(1, 0, 0, height)
		return frame
	end

	it("is a header and a closed body by default", function()
		local c = Collapsible.new({ app = app, Parent = gui, text = "Settings", content = box(80) })
		expect(c.Instance:HasTag("ui-collapsible")).to.equal(true)
		expect(c.Instance:HasTag("ui-collapsible-variant-default")).to.equal(true)
		expect(c.header:IsA("TextButton")).to.equal(true)
		expect(c.label.Text).to.equal("Settings")
		expect(c:get("open")).to.equal(false)
		expect(c.body.Visible).to.equal(false)
		expect(c.body.Size.Y.Offset).to.equal(0)
		expect(c.body.ClipsDescendants).to.equal(true)
		expect(c.content:FindFirstChild("Box")).to.be.ok()
	end)

	it("opens with a short height tween once on screen", function()
		local c = Collapsible.new({ app = app, Parent = gui, content = box(80) })
		Harness.flush()
		-- The content's height (80 plus its padding), in the body's units.
		local full = math.round(c.content.AbsoluteSize.Y / Scroll.scaleOf(c.content))
		expect(full >= 80).to.equal(true)
		c:toggle()
		expect(c:get("open")).to.equal(true)
		expect(c.body.Visible).to.equal(true)
		Animate.step(1 / 20)
		local mid = c.body.Size.Y.Offset
		expect(mid > 0 and mid < full).to.equal(true)
		settle(0.3)
		expect(c.body.Size.Y.Offset).to.equal(full)
		c:toggle()
		settle(0.3)
		expect(c.body.Size.Y.Offset).to.equal(0)
		expect(c.body.Visible).to.equal(false)
	end)

	it("opens at once when not on screen yet", function()
		local c = Collapsible.new({ app = app, open = true, content = box(80) })
		expect(c.body.Visible).to.equal(true)
		expect(c.chevron.Instance.Rotation).to.equal(180)
		c:set("open", false)
		expect(c.body.Visible).to.equal(false)
		expect(c.chevron.Instance.Rotation).to.equal(0)
		c:destroy()
	end)

	it("turns the chevron: down to up, or right to down for details", function()
		local c = Collapsible.new({ app = app, Parent = gui })
		expect(c.chevron:get("icon")).to.equal("lucy:chevron-down")
		c:toggle()
		settle(0.3)
		expect(c.chevron.Instance.Rotation).to.equal(180)
		-- A list layout drops the rotation of what it places, so check it is drawn.
		task.wait()
		expect(c.chevron.Instance.AbsoluteRotation).to.equal(180)
		local d = Collapsible.new({ app = app, Parent = gui, variant = "details" })
		expect(d.chevron:get("icon")).to.equal("lucy:chevron-right")
		d:toggle()
		settle(0.3)
		expect(d.chevron.Instance.Rotation).to.equal(90)
	end)

	it("puts the chevron after the label, or before it for details", function()
		local c = Collapsible.new({ app = app, Parent = gui, text = "A" })
		local holder = c.chevron.Instance.Parent :: GuiObject
		expect(holder.Parent).to.equal(c.header)
		expect(holder.LayoutOrder > c.label.LayoutOrder).to.equal(true)
		c:set("variant", "details")
		expect(holder.LayoutOrder < c.label.LayoutOrder).to.equal(true)
		expect(c.Instance:HasTag("ui-collapsible-variant-details")).to.equal(true)
		expect(c.content:HasTag("ui-collapsible-content-variant-details")).to.equal(true)
	end)

	it("rejects an unknown variant", function()
		expect(function()
			Collapsible.new({ app = app, Parent = gui, variant = "fancy" })
		end).to.throw()
	end)

	it("keeps open in step with a ref, both ways, and reports changes", function()
		local open = Reactive.ref(true)
		local seen = {}
		local c = Collapsible.new({
			app = app,
			Parent = gui,
			open = open,
			onOpenChange = function(value)
				table.insert(seen, tostring(value))
			end,
		})
		c:toggle()
		expect(open()).to.equal(false)
		open(true)
		expect(c:get("open")).to.equal(true)
		expect(table.concat(seen, ",")).to.equal("false,true")
	end)

	it("ignores the player while disabled", function()
		local c = Collapsible.new({ app = app, Parent = gui, disabled = true })
		c:toggle()
		expect(c:get("open")).to.equal(false)
		expect(c.header.Selectable).to.equal(false)
		expect(c.header:HasTag("ui-disabled")).to.equal(true)
	end)

	it("emits toggle with the open state from the player path only", function()
		local calls = {}
		local scope = Reactive.effectScope(true)
		local c = scope:run(function()
			Composables.useUiSound(app, {
				toggle = function(_, value)
					table.insert(calls, tostring(value))
				end,
			})
			return Collapsible.new({ app = app, Parent = gui })
		end)
		c:toggle()
		c:set("open", false)
		c:toggle()
		c:toggle()
		expect(table.concat(calls, ",")).to.equal("true,true,false")
		scope:stop()
	end)

	it("opens and closes when Enter is pressed on its header", function()
		local inner = Instance.new("TextButton")
		inner.Name = "Inner"
		local c = Collapsible.new({ app = app, Parent = gui, open = true, content = inner })
		expect(c:press(inner)).to.equal(false)
		app.input:focus(c.header)
		app.input:activate()
		expect(c:get("open")).to.equal(false)
		app.input:activate()
		expect(c:get("open")).to.equal(true)
	end)

	it("opens at once with reduced motion", function()
		local Preferences = require(script.Parent.Parent.Core.Preferences)
		Preferences.setReducedMotion(true)
		local ok, err = pcall(function()
			local c = Collapsible.new({ app = app, Parent = gui, content = box(80) })
			Harness.flush()
			c:toggle()
			expect(c.body.Size.Y.Offset > 0).to.equal(true)
			expect(c.chevron.Instance.Rotation).to.equal(180)
		end)
		Preferences.setReducedMotion(nil)
		assert(ok, err)
	end)

	it("pads the content in from the sides, more on the chevron side", function()
		local c = Collapsible.new({
			app = app,
			Parent = gui,
			text = "Music",
			open = true,
			content = box(20),
		})
		c.Instance.Size = UDim2.fromOffset(300, 0)
		Harness.flush()
		settle(0.5)
		local inner = c.content:FindFirstChild("Box") :: Frame
		local scale = Scroll.scaleOf(c.Instance)
		local left = (inner.AbsolutePosition.X - c.Instance.AbsolutePosition.X) / scale
		local right = (
			(c.Instance.AbsolutePosition.X + c.Instance.AbsoluteSize.X)
			- (inner.AbsolutePosition.X + inner.AbsoluteSize.X)
		) / scale
		expect(math.abs(left - 12) <= 1).to.equal(true)
		expect(math.abs(right - 24) <= 1).to.equal(true)
	end)
end
