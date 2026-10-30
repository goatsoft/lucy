return function()
	local Overlay = require(script.Parent.Overlay)
	local Reactive = require(script.Parent.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app()
	end)
	afterEach(function()
		cleanup()
	end)

	-- Runs Overlay.use in a detached scope; returns the overlay, its open ref and the scope.
	local function make(options: { [string]: any }?)
		local opts = table.clone(options or {})
		local open = opts.open or Reactive.ref(false)
		opts.open = open
		if opts.content == nil then
			local content = Instance.new("Frame")
			content.Size = UDim2.fromOffset(200, 120)
			local button = Instance.new("TextButton")
			button.Name = "Inside"
			button.Size = UDim2.fromOffset(100, 30)
			button.Parent = content
			opts.content = content
		end
		local scope = Reactive.effectScope(true)
		local overlay
		scope:run(function()
			overlay = Overlay.use(app, opts)
		end)
		return overlay, open, scope
	end

	describe("resolve", function()
		it("picks a drawer on touch and the preferred shape elsewhere", function()
			expect(Overlay.resolve("auto", "popup", "touch")).to.equal("drawer")
			expect(Overlay.resolve("auto", "panel", "touch")).to.equal("drawer")
			expect(Overlay.resolve("auto", "popup", "mouse")).to.equal("popup")
			expect(Overlay.resolve("auto", "panel", "gamepad")).to.equal("panel")
			expect(Overlay.resolve("auto", nil, "keyboard")).to.equal("popup")
			expect(Overlay.resolve("center", nil, "touch")).to.equal("center")
		end)
	end)

	describe("place", function()
		local view = Vector2.new(800, 600)
		local function anchor(x, y, w, h)
			return { position = Vector2.new(x, y), size = Vector2.new(w, h) }
		end

		it("puts a popup under its anchor, at least as wide, aligned to its start", function()
			local at = Overlay.place("popup", {
				view = view,
				anchor = anchor(100, 100, 160, 32),
				content = Vector2.new(120, 200),
			})
			expect(at.side).to.equal("bottom")
			expect(at.anchorPoint).to.equal(Vector2.new(0, 0))
			expect(at.position).to.equal(UDim2.fromOffset(100, 136))
			expect(at.width).to.equal(160)
			expect(at.maxHeight).to.equal(600 - 136 - 8)
		end)

		it("flips a popup above when there is more room there", function()
			local at = Overlay.place("popup", {
				view = view,
				anchor = anchor(100, 500, 160, 32),
				content = Vector2.new(160, 200),
			})
			expect(at.side).to.equal("top")
			expect(at.anchorPoint).to.equal(Vector2.new(0, 1))
			expect(at.position).to.equal(UDim2.fromOffset(100, 496))
			expect(at.maxHeight).to.equal(496 - 8)
		end)

		it("keeps a popup below when it fits, even with more room above", function()
			local at = Overlay.place("popup", {
				view = view,
				anchor = anchor(100, 400, 160, 32),
				content = Vector2.new(160, 100),
			})
			expect(at.side).to.equal("bottom")
		end)

		it("clamps a popup inside the viewport and aligns its end", function()
			local at = Overlay.place("popup", {
				view = view,
				anchor = anchor(700, 100, 90, 32),
				content = Vector2.new(240, 100),
				width = 240,
			})
			expect(at.width).to.equal(240)
			expect(at.position.X.Offset).to.equal(800 - 240 - 8)
			local ending = Overlay.place("popup", {
				view = view,
				anchor = anchor(300, 100, 100, 32),
				content = Vector2.new(160, 100),
				width = 160,
				align = "end",
			})
			expect(ending.position.X.Offset).to.equal(240)
		end)

		it("fills the bottom for a drawer and a side for a panel", function()
			local drawer = Overlay.place("drawer", { view = view, content = Vector2.new(0, 100) })
			expect(drawer.anchorPoint).to.equal(Vector2.new(0, 1))
			expect(drawer.position).to.equal(UDim2.fromScale(0, 1))
			expect(drawer.widthScale).to.equal(1)
			expect(drawer.maxHeight).to.equal(math.floor(600 * 0.85))

			local right = Overlay.place("panel", { view = view, content = Vector2.zero })
			expect(right.anchorPoint).to.equal(Vector2.new(1, 0))
			expect(right.position).to.equal(UDim2.fromScale(1, 0))
			expect(right.width).to.equal(360)
			expect(right.fullHeight).to.equal(true)
			local left = Overlay.place(
				"panel",
				{ view = Vector2.new(300, 600), content = Vector2.zero, panelSide = "left" }
			)
			expect(left.anchorPoint).to.equal(Vector2.new(0, 0))
			expect(left.width).to.equal(270)
		end)

		it("centres, and falls back to the centre for a popup with no anchor", function()
			local center = Overlay.place("center", { view = view, content = Vector2.new(300, 200) })
			expect(center.anchorPoint).to.equal(Vector2.new(0.5, 0.5))
			expect(center.position).to.equal(UDim2.fromScale(0.5, 0.5))
			expect(center.maxHeight).to.equal(600 - 64)
			local loose = Overlay.place("popup", { view = view, content = Vector2.new(300, 200) })
			expect(loose.anchorPoint).to.equal(Vector2.new(0.5, 0.5))
		end)
	end)

	describe("use", function()
		it("needs an owner", function()
			expect(function()
				Overlay.use(app, { open = Reactive.ref(false), content = Instance.new("Frame") })
			end).to.throw()
		end)

		it("mounts into the modal portal and shows while open", function()
			local overlay, open, scope = make()
			expect(overlay.root.Parent).to.equal(app:portal("modal"))
			expect(overlay.root.Visible).to.equal(false)
			open(true)
			expect(overlay.root.Visible).to.equal(true)
			open(false)
			expect(overlay.root.Visible).to.equal(false)
			scope:stop()
		end)

		it("stacks the newest open overlay on top", function()
			local a, openA, scopeA = make()
			local b, openB, scopeB = make()
			openA(true)
			openB(true)
			expect(b.root.ZIndex > a.root.ZIndex).to.equal(true)
			openA(false)
			openA(true)
			expect(a.root.ZIndex > b.root.ZIndex).to.equal(true)
			scopeA:stop()
			scopeB:stop()
		end)

		it("publishes how many are open, how many are modal, and the top one", function()
			local a, openA, scopeA = make({ id = "first" })
			local _, openB, scopeB = make({ id = "loose", modal = false })
			expect(app.state:get("overlay.count")).to.equal(0)
			openA(true)
			openB(true)
			expect(app.state:get("overlay.count")).to.equal(2)
			expect(app.state:get("overlay.modal")).to.equal(1)
			expect(app.state:get("overlay.top")).to.equal("loose")
			openB(false)
			expect(app.state:get("overlay.top")).to.equal("first")
			expect(app.state:get("overlay.modal")).to.equal(1)
			scopeA:stop()
			expect(app.state:get("overlay.count")).to.equal(0)
			expect(app.state:get("overlay.top")).to.equal(nil)
			expect(a.root.Parent).to.equal(nil)
			scopeB:stop()
		end)

		it("tells the app whether a modal one is open, and updates readers", function()
			local open = Reactive.computed(function()
				return app:modalOpen()
			end)
			expect(open()).to.equal(false)
			local _, openA, scopeA = make({ id = "first" })
			local _, openB, scopeB = make({ id = "loose", modal = false })
			openB(true)
			expect(open()).to.equal(false)
			openA(true)
			expect(open()).to.equal(true)
			openA(false)
			expect(open()).to.equal(false)
			scopeA:stop()
			scopeB:stop()
		end)

		it("is a focus scope with a stopped selection group when modal", function()
			local overlay, open, scope = make()
			open(true)
			expect(app.input:topScope().root).to.equal(overlay.content)
			expect(overlay.content.SelectionGroup).to.equal(true)
			expect(overlay.scrim:IsA("TextButton")).to.equal(true)
			open(false)
			local top = app.input:topScope()
			expect(top == nil or top.root ~= overlay.content).to.equal(true)
			scope:stop()
		end)

		it("lets input through when not modal", function()
			local overlay, open, scope = make({ modal = false })
			open(true)
			local top = app.input:topScope()
			expect(top == nil or top.root ~= overlay.content).to.equal(true)
			expect(overlay.scrim:IsA("TextButton")).to.equal(false)
			expect(overlay.scrim.Active).to.equal(false)
			expect(overlay.content.SelectionGroup).to.equal(false)
			scope:stop()
		end)

		it("dims by default for a centred modal and not for a popup", function()
			local center, openCenter, scopeCenter = make({ presentation = "center" })
			openCenter(true)
			expect(center.scrim:HasTag("ui-overlay-scrim")).to.equal(true)
			expect(center.scrim.Visible).to.equal(true)
			local bare, openBare, scopeBare = make({ presentation = "center", scrim = false })
			openBare(true)
			expect(bare.scrim:HasTag("ui-overlay-scrim")).to.equal(false)
			expect(bare.scrim.Visible).to.equal(true) -- still catches presses
			local popup, openPopup, scopePopup = make({ presentation = "popup" })
			openPopup(true)
			expect(popup.scrim:HasTag("ui-overlay-scrim")).to.equal(false)
			Harness.flush()
			expect(Harness.styled(center.scrim, "BackgroundTransparency")).to.be.near(
				app.theme:resolve("OverlayTransparency"),
				0.001
			)
			scopeCenter:stop()
			scopeBare:stop()
			scopePopup:stop()
		end)

		it("closes on back when dismissible and holds it when not", function()
			local reasons = {}
			local _, open, scope = make({
				onClose = function(reason)
					table.insert(reasons, reason)
				end,
			})
			open(true)
			expect(app.input:back()).to.equal(true)
			expect(open()).to.equal(false)
			expect(reasons[1]).to.equal("back")

			local _, stuckOpen, stuckScope = make({ dismissible = false })
			stuckOpen(true)
			expect(app.input:back()).to.equal(true)
			expect(stuckOpen()).to.equal(true)
			scope:stop()
			stuckScope:stop()
		end)

		it("reports a close from code", function()
			local reasons = {}
			local overlay, open, scope = make({
				onClose = function(reason)
					table.insert(reasons, reason)
				end,
			})
			open(true)
			overlay.close()
			expect(open()).to.equal(false)
			open(true)
			open(false)
			expect(reasons[1]).to.equal("code")
			expect(reasons[2]).to.equal("code")
			scope:stop()
		end)

		it("closes when its anchor goes away", function()
			local gui = Harness.mount(app)
			local trigger = Instance.new("TextButton")
			trigger.Parent = gui
			local reasons = {}
			local _, open, scope = make({
				presentation = "popup",
				anchor = trigger,
				onClose = function(reason)
					table.insert(reasons, reason)
				end,
			})
			open(true)
			trigger.Visible = false
			task.wait()
			expect(open()).to.equal(false)
			expect(reasons[1]).to.equal("anchor")
			trigger.Visible = true
			open(true)
			trigger:Destroy()
			task.wait()
			expect(open()).to.equal(false)
			scope:stop()
		end)

		it("decides auto presentation when it opens, not while open", function()
			app.input:setMode("touch")
			local overlay, open, scope = make({ presentation = "auto", prefer = "popup" })
			open(true)
			expect(overlay.presentation()).to.equal("drawer")
			app.input:setMode("mouse")
			expect(overlay.presentation()).to.equal("drawer")
			open(false)
			open(true)
			expect(overlay.presentation()).to.equal("popup")
			scope:stop()
		end)

		it("gives focus back to the anchor on gamepad", function()
			local gui = Harness.mount(app)
			local trigger = Instance.new("TextButton")
			trigger.Position = UDim2.fromOffset(0, 400)
			trigger.Parent = gui
			app.input:setMode("gamepad")
			app.input:focus(trigger)
			local overlay, open, scope = make({ presentation = "popup", anchor = trigger })
			open(true)
			expect(app.input:focused()).to.equal(overlay.content:FindFirstChild("Inside"))
			open(false)
			expect(app.input:focused()).to.equal(trigger)
			scope:stop()
		end)

		it("places the content and offers a height cap while open", function()
			local gui = Harness.mount(app)
			local trigger = Instance.new("TextButton")
			trigger.Size = UDim2.fromOffset(160, 32)
			trigger.Position = UDim2.fromOffset(40, 40)
			trigger.Parent = gui
			local overlay, open, scope = make({ presentation = "popup", anchor = trigger })
			open(true)
			task.wait(0.2)
			local content = overlay.content
			local scale = (content.AbsoluteSize.X / content.Size.X.Offset)
			expect(content.Size.X.Offset).to.equal(160)
			expect(math.abs(content.AbsolutePosition.X - trigger.AbsolutePosition.X) <= 2).to.equal(true)
			expect(content.AbsolutePosition.Y >= trigger.AbsolutePosition.Y + trigger.AbsoluteSize.Y).to.equal(
				true
			)
			expect(overlay.maxHeight() > 0).to.equal(true)
			expect(scale > 0).to.equal(true)
			scope:stop()
		end)
	end)
end
