return function()
	local Dialog = require(script.Parent.Dialog)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
	end)
	afterEach(function()
		cleanup()
	end)

	it("keeps open in step with a ref, both ways", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local open = Reactive.ref(false)
		local round = Reactive.ref(1)
		local dialog = Dialog.new({
			app = app,
			open = open,
			title = function()
				return `Round {round()}`
			end,
		})
		expect(dialog.Instance.Visible).to.equal(false)
		open(true)
		expect(dialog.Instance.Visible).to.equal(true)
		round(2)
		expect(dialog.titleLabel.Text).to.equal("Round 2")
		dialog:close()
		expect(open()).to.equal(false)
		expect(dialog.Instance.Visible).to.equal(false)
	end)

	it("mounts closed into the modal portal", function()
		local dialog = Dialog.new({ app = app, title = "Hi" })
		expect(dialog.Instance.Parent).to.equal(app:portal("modal"))
		expect(dialog.Instance.Visible).to.equal(false)
		expect(dialog.titleLabel.Text).to.equal("Hi")
	end)

	it("opens and closes from methods and app state", function()
		local dialog = Dialog.new({ app = app, id = "quit" })
		dialog:open()
		expect(dialog.Instance.Visible).to.equal(true)
		app.state:set("ui.quit.open", false)
		expect(dialog.Instance.Visible).to.equal(false)
		dialog:toggle()
		expect(app.state:get("ui.quit.open")).to.equal(true)
	end)

	it("reports open changes", function()
		local changes = {}
		local dialog = Dialog.new({
			app = app,
			onOpenChange = function(open)
				table.insert(changes, open)
			end,
		})
		dialog:open()
		dialog:close()
		expect(#changes).to.equal(2)
		expect(changes[1]).to.equal(true)
		expect(changes[2]).to.equal(false)
	end)

	it("closes after an action unless it returns false", function()
		local ran = 0
		local dialog = Dialog.new({
			app = app,
			open = true,
			actions = {
				{
					text = "Keep",
					onClick = function()
						ran += 1
						return false
					end,
				},
				{
					text = "Go",
					onClick = function()
						ran += 1
					end,
				},
			},
		})
		dialog.actions[1]:click()
		expect(dialog:get("open")).to.equal(true)
		task.wait(0.06)
		dialog.actions[2]:click()
		expect(dialog:get("open")).to.equal(false)
		expect(ran).to.equal(2)
	end)

	it("closes on back when dismissible and blocks it when not", function()
		local dialog = Dialog.new({ app = app, open = true })
		expect(app.input:back()).to.equal(true)
		expect(dialog:get("open")).to.equal(false)

		local alert = Dialog.alert({ app = app, title = "Sure?" })
		expect(app.input:back()).to.equal(true)
		expect(alert:get("open")).to.equal(true)
	end)

	it("is a focus scope while open", function()
		local dialog = Dialog.new({ app = app, actions = { { text = "OK" } } })
		dialog:open()
		expect(app.input:topScope().root).to.equal(dialog.content)
		expect(dialog.content.SelectionGroup).to.equal(true)
		dialog:close()
		local top = app.input:topScope()
		expect(top == nil or top.root ~= dialog.content).to.equal(true)
	end)

	it("selects the primary action when opened on a gamepad", function()
		app.input:setMode("gamepad")
		local dialog = Dialog.new({ app = app, actions = { { text = "No" }, { text = "Yes" } } })
		dialog:open()
		expect(dialog.actions[2].Instance:HasTag("ui-focus-visible")).to.equal(true)
	end)

	it("builds alert dialogs with cancel and confirm", function()
		local confirmed = false
		local alert = Dialog.alert({
			app = app,
			title = "Delete?",
			destructive = true,
			onConfirm = function()
				confirmed = true
			end,
		})
		expect(alert:get("open")).to.equal(true)
		expect(alert.closeButton).to.equal(nil)
		expect(alert.actions[2].Instance:HasTag("ui-button-variant-destructive")).to.equal(true)
		alert.actions[2]:click()
		expect(confirmed).to.equal(true)
		expect(alert:get("open")).to.equal(false)
	end)

	it("can open with no backdrop and without trapping input", function()
		local bare = Dialog.new({ app = app, open = true, scrim = false })
		expect(bare.overlay:HasTag("ui-overlay-scrim")).to.equal(false)
		expect(app.input:topScope().root).to.equal(bare.content)

		local loose = Dialog.new({ app = app, open = true, modal = false, actions = { { text = "OK" } } })
		expect(app.input:topScope().root).never.to.equal(loose.content)
		expect(loose.overlay.Active).to.equal(false)
		expect(loose.overlay:HasTag("ui-overlay-scrim")).to.equal(false)
		expect(app.state:get("overlay.count")).to.equal(2)
		expect(app.state:get("overlay.modal")).to.equal(1)
		expect(app.input:back()).to.equal(true)
		expect(loose:get("open")).to.equal(false)
	end)

	it("stacks a dialog opened later above an earlier one", function()
		local first = Dialog.new({ app = app, open = true })
		local second = Dialog.new({ app = app, open = true })
		expect(second.Instance.ZIndex > first.Instance.ZIndex).to.equal(true)
	end)

	it("gives focus back to what had it on gamepad", function()
		local gui = Harness.mount(app)
		local opener = Instance.new("TextButton")
		opener.Position = UDim2.fromOffset(0, 400)
		opener.Parent = gui
		app.input:setMode("gamepad")
		app.input:focus(opener)
		local dialog = Dialog.new({ app = app, actions = { { text = "OK" } } })
		dialog:open()
		expect(app.input:focused()).to.equal(dialog.actions[1].Instance)
		dialog:close()
		expect(app.input:focused()).to.equal(opener)
	end)

	it("puts the close button in the top right corner", function()
		local dialog = Dialog.new({ app = app, open = true, title = "Hi" })
		task.wait(0.2)
		local close = dialog.closeButton.Instance
		expect(close.Parent).to.equal(dialog.content)
		local c = dialog.content
		local right = c.AbsolutePosition.X + c.AbsoluteSize.X
		local gapRight = right - (close.AbsolutePosition.X + close.AbsoluteSize.X)
		local gapTop = close.AbsolutePosition.Y - c.AbsolutePosition.Y
		expect(gapRight >= 0 and gapRight <= 12).to.equal(true)
		expect(gapTop >= 0 and gapTop <= 12).to.equal(true)
	end)

	it("dims the screen with the overlay token", function()
		local dialog = Dialog.new({ app = app, open = true })
		Harness.flush()
		expect(Harness.styled(dialog.overlay, "BackgroundTransparency")).to.equal(
			app.theme:resolve("OverlayTransparency")
		)
	end)
end
