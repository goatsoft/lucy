return function()
	local Pressable = require(script.Parent.Pressable)
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

	it("holds any children and reports clicks", function()
		local clicks, fired = 0, 0
		local icon = Instance.new("ImageLabel")
		local pressable
		pressable = Pressable.new({
			app = app,
			Parent = gui,
			children = { icon },
			onClick = function(handle)
				expect(handle).to.equal(pressable)
				clicks += 1
			end,
		})
		pressable.Activated:Connect(function()
			fired += 1
		end)
		expect(icon.Parent).to.equal(pressable.Instance)
		expect(pressable.Instance.Selectable).to.equal(true)
		pressable:click()
		expect(clicks).to.equal(1)
		expect(fired).to.equal(1)
	end)

	it("follows reactive selected and disabled", function()
		local selected, disabled = Reactive.ref(false), Reactive.ref(false)
		local clicks = 0
		local pressable = Pressable.new({
			app = app,
			Parent = gui,
			selected = selected,
			disabled = disabled,
			onClick = function()
				clicks += 1
			end,
		})
		local root = pressable.Instance
		expect(root:HasTag("ui-selected")).to.equal(false)
		selected(true)
		expect(root:HasTag("ui-selected")).to.equal(true)
		disabled(true)
		expect(root:HasTag("ui-disabled")).to.equal(true)
		expect(root.Interactable).to.equal(false)
		expect(root.Selectable).to.equal(false)
		pressable:click()
		expect(clicks).to.equal(0)
	end)

	it("sizes to its content unless given a size", function()
		local fits = Pressable.new({ app = app, Parent = gui })
		expect(fits.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
		local fixed = Pressable.new({ app = app, Parent = gui, size = UDim2.fromOffset(120, 80) })
		expect(fixed.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.None)
		expect(fixed.Instance.Size).to.equal(UDim2.fromOffset(120, 80))
	end)

	it("pads its content", function()
		local pressable = Pressable.new({ app = app, Parent = gui, padding = 12 })
		local padding = pressable.Instance:FindFirstChildOfClass("UIPadding")
		expect(padding).to.be.ok()
		expect(padding.PaddingTop).to.equal(UDim.new(0, 12))
		expect(padding.PaddingLeft).to.equal(UDim.new(0, 12))
	end)

	it("uses the accent colour when selected", function()
		local pressable = Pressable.new({ app = app, Parent = gui, selected = true })
		Harness.flush()
		expect(
			Harness.colorEq(
				Harness.styled(pressable.Instance, "BackgroundColor3"),
				app.theme:resolve("Accent")
			)
		).to.equal(true)
	end)
end
