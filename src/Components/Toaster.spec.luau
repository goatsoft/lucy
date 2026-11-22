return function()
	local Toaster = require(script.Parent.Toaster)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	describe("list operations", function()
		local function toast(id, createdAt, duration)
			return { id = id, createdAt = createdAt or 0, duration = duration or 4 }
		end

		it("adds new toasts at the end and replaces by id in place", function()
			local list = Toaster.add({}, toast("a"))
			list = Toaster.add(list, toast("b"))
			list = Toaster.add(list, { id = "a", title = "updated", createdAt = 0, duration = 4 })
			expect(#list).to.equal(2)
			expect(list[1].title).to.equal("updated")
		end)

		it("dismisses one or all", function()
			local list = { toast("a"), toast("b") }
			expect(#Toaster.dismiss(list, "a")).to.equal(1)
			expect(#Toaster.dismiss(list)).to.equal(0)
			expect(Toaster.dismiss(list, "zzz")).to.equal(list)
		end)

		it("throws a toast away past its edge or far enough sideways", function()
			local far = Toaster.SWIPE + 1
			expect(Toaster.swiped(Vector2.new(0, -far), true)).to.equal(true)
			expect(Toaster.swiped(Vector2.new(0, far), true)).to.equal(false)
			expect(Toaster.swiped(Vector2.new(0, far), false)).to.equal(true)
			expect(Toaster.swiped(Vector2.new(far, 0), true)).to.equal(false)
			expect(Toaster.swiped(Vector2.new(-far * 2, 0), true)).to.equal(true)
		end)

		it("expires by duration and keeps sticky toasts", function()
			local list = { toast("a", 0, 4), toast("b", 0, math.huge), toast("c", 3, 4) }
			local after = Toaster.expire(list, 5)
			expect(#after).to.equal(2)
			expect(after[1].id).to.equal("b")
			expect(Toaster.expire(list, 1)).to.equal(list)
		end)
	end)

	describe("app.toast", function()
		local app, cleanup, now
		beforeEach(function()
			app, cleanup = Harness.app({ theme = "light" })
			now = 0
			app.clock = function()
				return now
			end
		end)
		afterEach(function()
			cleanup()
		end)

		it("mounts again in the toast portal when the one it was in is taken away", function()
			app.toast("Doors open")
			local first = app:portal("toast")
			expect(first:FindFirstChild("Toaster", true)).to.be.ok()
			-- Taken out of the screen without being destroyed: the app makes a new portal
			first.Parent = nil
			app.toast("Show at eight")
			local portal = app:portal("toast")
			expect(portal).never.to.equal(first)
			expect(portal:FindFirstChild("Toaster", true)).to.be.ok()
			expect(#app.toast.list()).to.equal(2)
		end)

		it("follows a reactive visible", function()
			local Reactive = require(script.Parent.Parent.Core.Reactive)
			local inMenu = Reactive.ref(false)
			local toaster = Toaster.new({
				app = app,
				Parent = app:portal("toast"),
				visible = function()
					return not inMenu()
				end,
			})
			expect(toaster.Instance.Visible).to.equal(true)
			inMenu(true)
			expect(toaster.Instance.Visible).to.equal(false)
			expect(toaster:get("visible")).to.equal(false)
			inMenu(false)
			expect(toaster.Instance.Visible).to.equal(true)
			toaster:destroy()
		end)

		it("sits where position says, set on the app or changed later", function()
			local other, stop = Harness.app({ namePrefix = "ToastPos_", toastPosition = "top-left" })
			local ok, err = pcall(function()
				other.toast("Hi")
				local toaster = other:handle("toaster")
				local root = toaster.Instance
				expect(toaster:get("position")).to.equal("top-left")
				expect(root.AnchorPoint).to.equal(Vector2.new(0, 0))
				expect(toaster.layout.VerticalAlignment).to.equal(Enum.VerticalAlignment.Top)
				expect(toaster.layout.HorizontalAlignment).to.equal(Enum.HorizontalAlignment.Left)
				other.state:set("ui.toaster.position", "bottom-center")
				expect(root.AnchorPoint).to.equal(Vector2.new(0.5, 1))
				expect(root.Position).to.equal(UDim2.fromScale(0.5, 1))
				expect(toaster.layout.VerticalAlignment).to.equal(Enum.VerticalAlignment.Bottom)
				expect(toaster.layout.HorizontalAlignment).to.equal(Enum.HorizontalAlignment.Center)
			end)
			stop()
			assert(ok, err)
		end)

		it("sits just off the top where the top bar is free, under it only where its buttons are", function()
			local Toaster = require(script.Parent.Toaster) :: any
			local read = Toaster._topbar
			-- Roblox's buttons on the left, 300 pixels of them; the bar is 40 tall
			local bar = Rect.new(300, 0, 2000, 40)
			Toaster._topbar = function()
				return bar
			end
			local other, stop = Harness.app({ namePrefix = "ToastBar_", toastPosition = "top-center" })
			local ok, err = pcall(function()
				other.toast("Show in progress")
				local toaster = other:handle("toaster")
				local padding = toaster.container:FindFirstChildOfClass("UIPadding") :: UIPadding
				-- A toast clear of the buttons sits just off the very top (measured, so only where the
				-- screen lays out: not on a running server)
				if Harness.laysOutLive() then
					expect(Harness.waitFor(function()
						return padding.PaddingTop.Offset == 24
					end)).to.equal(true)
				end
				-- One that would reach under them drops below the bar
				other.state:set("ui.toaster.position", "top-left")
				expect(Harness.waitFor(function()
					return padding.PaddingTop.Offset == 24 + 40
				end)).to.equal(true)
			end)
			stop()
			Toaster._topbar = read
			assert(ok, err)
		end)

		it("knows whether a span fits the free part of the top bar", function()
			local Toaster = require(script.Parent.Toaster) :: any
			local free = Rect.new(300, 0, 1200, 40)
			expect(Toaster.clearsTopbar(400, 900, free)).to.equal(true)
			expect(Toaster.clearsTopbar(250, 900, free)).to.equal(false)
			expect(Toaster.clearsTopbar(400, 1250, free)).to.equal(false)
			-- No bar (a console, or no top bar at all): nothing to clear
			expect(Toaster.clearsTopbar(0, 900, Rect.new(0, 0, 0, 0))).to.equal(true)
		end)

		it("puts the newest toast nearest its edge", function()
			local first = app.toast("First")
			local second = app.toast("Second")
			local portal = app:portal("toast")
			-- A toast's panel sits in its frame (Core/PanelFrame), which the list lays out
			local function order(id)
				return portal:FindFirstChild(id, true).Parent.LayoutOrder
			end
			expect(order(second) > order(first)).to.equal(true)
			app.state:set("ui.toaster.position", "top-right")
			expect(order(second) < order(first)).to.equal(true)
		end)

		it("takes its width from the app's toastWidth", function()
			local other, stop = Harness.app({ namePrefix = "ToastWide_", toastWidth = 480 })
			local ok, err = pcall(function()
				other.toast("Hi")
				local container = other:handle("toaster").container
				-- The column, and its inset each side, never wider than the screen
				local limit = container:FindFirstChildOfClass("UISizeConstraint")
				expect(limit.MaxSize.X).to.equal(480 + 24 * 2)
				expect(container.Size).to.equal(UDim2.fromScale(1, 1))
			end)
			stop()
			if not ok then
				error(err, 0)
			end
		end)

		it("rejects an unknown position", function()
			expect(function()
				Toaster.new({ app = app, Parent = app:portal("toast"), position = "middle" })
			end).to.throw()
		end)

		it("closes with an icon button, not a text glyph", function()
			local id = app.toast("Hello")
			local close = app:portal("toast"):FindFirstChild(id, true):FindFirstChild("Close", true)
			expect(close.Text).to.equal("")
			expect(close:FindFirstChild("Icon") ~= nil).to.equal(true)
		end)

		it("puts media before the title and description, in the toast's text colour", function()
			local Icon = require(script.Parent.Icon)
			local plain = app.toast("Saved")
			local won = app.toast.success("Won", {
				description = "+$250",
				media = Icon.new({ app = app, icon = "lucy:check", size = 36 }),
			})
			Harness.flush()
			local function row(id)
				return app:portal("toast"):FindFirstChild(id, true).Row
			end
			expect(row(plain):FindFirstChild("Media")).to.equal(nil)
			local media = row(won).Media
			expect(media.LayoutOrder < row(won).Body.LayoutOrder).to.equal(true)
			local icon = media:FindFirstChildWhichIsA("ImageLabel")
			local colour = Harness.styled(icon, "ImageColor3")
			expect(Harness.colorEq(colour, app.theme:resolve("SuccessForeground"))).to.equal(true)
		end)

		it("is installed on every app", function()
			expect(app.toast).to.be.ok()
			expect(app.state:get("toasts")).to.be.ok()
		end)

		it("stores toasts in app state and returns ids", function()
			local id = app.toast.success("Saved", { description = "All good" })
			local list = app.state:get("toasts")
			expect(#list).to.equal(1)
			expect(list[1].id).to.equal(id)
			expect(list[1].kind).to.equal("success")
			expect(list[1].description).to.equal("All good")
		end)

		it("renders into the toast portal", function()
			local id = app.toast("Hello")
			local portal = app:portal("toast")
			local frame = portal:FindFirstChild(id, true)
			expect(frame).to.be.ok()
			expect(frame.Row.Body.Title.Text).to.equal("Hello")
		end)

		it("puts the game's own UI in a toast, in its panel or bare", function()
			local made = 0
			local function card(): Frame
				made += 1
				local f = Instance.new("Frame")
				f.Name = "Card"
				f.Size = UDim2.fromOffset(200, 40)
				return f
			end
			local portal = app:portal("toast")
			local inPanel = app.toast("Show", { content = card })
			local panel = portal:FindFirstChild(inPanel, true)
			expect(panel.Row.Body:FindFirstChild("Card")).to.be.ok()
			expect(panel.Row.Body:FindFirstChild("Title")).to.equal(nil)
			local bare =
				app.toast("Show", { content = card, bare = true, duration = math.huge, id = "status" })
			local frame = portal:FindFirstChild(bare .. "-frame", true)
			expect(frame:HasTag("ui-toast-bare")).to.equal(true)
			expect(frame:FindFirstChild("Card", true)).to.be.ok()
			expect(frame:FindFirstChild("Close", true)).to.equal(nil)
			expect(portal:FindFirstChild(bare, true)).to.equal(nil) -- no panel of Lucy's
			-- Updated in place: the same card, not a new one
			app.toast("Show again", { content = card, bare = true, duration = math.huge, id = "status" })
			expect(made).to.equal(2)
			app.toast.dismiss("status")
			expect(portal:FindFirstChild("status-frame", true)).to.equal(nil)
		end)

		it("keeps the touch options on the toast", function()
			local id = app.toast("x", { dismissOnTap = true, swipe = false })
			local list = app.state:get("toasts")
			expect(list[1].id).to.equal(id)
			expect(list[1].dismissOnTap).to.equal(true)
			expect(list[1].swipe).to.equal(false)
			app.toast.success("y")
			expect(app.state:get("toasts")[2].swipe).to.equal(true)
		end)

		it("updates in place by id", function()
			local id = app.toast("Uploading", { duration = math.huge })
			app.toast("Uploaded", { id = id, kind = "success" })
			local list = app.toast.list()
			expect(#list).to.equal(1)
			expect(list[1].title).to.equal("Uploaded")
		end)

		it("expires on tick", function()
			app.toast("Bye", { duration = 2 })
			now = 1
			app.toast.tick()
			expect(#app.toast.list()).to.equal(1)
			now = 3
			app.toast.tick()
			expect(#app.toast.list()).to.equal(0)
		end)

		it("shows only the newest visibleToasts", function()
			for i = 1, 5 do
				app.toast("t" .. i)
			end
			local portal = app:portal("toast")
			expect(portal:FindFirstChild("toast-1", true).Parent.Visible).to.equal(false)
			expect(portal:FindFirstChild("toast-5", true).Parent.Visible).to.equal(true)
		end)

		it("runs the action and dismisses", function()
			local joined = false
			local id = app.toast("Invite", {
				action = {
					label = "Join",
					onClick = function()
						joined = true
					end,
				},
			})
			local toaster = nil
			for _, child in app:portal("toast"):GetChildren() do
				if child.Name == "toaster" or child:GetAttribute("LucyId") then
					toaster = app:handle(child:GetAttribute("LucyId"))
				end
			end
			toaster.entries[id].action:click()
			expect(joined).to.equal(true)
			expect(#app.toast.list()).to.equal(0)
		end)

		it("dismisses all", function()
			app.toast("a")
			app.toast("b")
			app.toast.dismiss()
			expect(#app.toast.list()).to.equal(0)
		end)

		it("rejects unknown kinds", function()
			expect(function()
				app.toast("x", { kind = "party" })
			end).to.throw()
		end)

		it("colours the whole toast by kind", function()
			local function parts(id)
				local frame = app:portal("toast"):FindFirstChild(id, true)
				return frame,
					frame.Row.Body.Title,
					frame.Row.Body.Description,
					frame:FindFirstChild("Icon", true)
			end
			local function is(instance, property, token)
				return Harness.colorEq(Harness.styled(instance, property), app.theme:resolve(token))
			end
			local plain = app.toast("Saved", { description = "All good" })
			local errored = app.toast.error("Nope", { description = "Try again" })
			local warned = app.toast.warning("Low ammo")
			Harness.flush()

			local frame, title, description, icon = parts(errored)
			expect(is(frame, "BackgroundColor3", "Destructive")).to.equal(true)
			expect(is(title, "TextColor3", "DestructiveForeground")).to.equal(true)
			expect(is(description, "TextColor3", "DestructiveForeground")).to.equal(true)
			expect(is(icon, "ImageColor3", "DestructiveForeground")).to.equal(true)

			frame, title = parts(warned)
			expect(is(frame, "BackgroundColor3", "Warning")).to.equal(true)
			expect(is(title, "TextColor3", "WarningForeground")).to.equal(true)

			frame, title = parts(plain)
			expect(is(frame, "BackgroundColor3", "Popover")).to.equal(true)
			expect(is(title, "TextColor3", "PopoverForeground")).to.equal(true)
		end)

		it("puts each toast in a panel frame, with no shadow or gradient unless the theme asks", function()
			local id = app.toast.success("Saved")
			local panel = app:portal("toast"):FindFirstChild(id, true)
			local frame = panel.Parent
			expect(frame:HasTag("ui-toast-frame")).to.equal(true)
			local shadow = frame:FindFirstChild("Shadow")
			expect(shadow).to.be.ok()
			expect(shadow:HasTag("ui-toast-shadow")).to.equal(true)
			expect(shadow.Visible).to.equal(false)
			local gradient = panel:FindFirstChildWhichIsA("UIGradient")
			expect(gradient == nil or gradient.Enabled == false).to.equal(true)
		end)
	end)

	describe("with a theme that frames toasts", function()
		local Tokens = require(script.Parent.Parent.Core.Tokens)
		local app, cleanup
		beforeEach(function()
			local primitives = table.clone(Tokens.primitives)
			primitives.PanelShadow = 6
			local themes = Tokens.themesFor("zinc")
			for _, values in themes do
				values.GradientToastSuccess = Tokens.gradient({ "$Green400", "$Green700" })
			end
			app, cleanup = Harness.app({ theme = "light", primitives = primitives, themes = themes })
		end)
		afterEach(function()
			cleanup()
		end)

		it("rounds the shadow's corners as the toast's own", function()
			-- The toast's corners are a style rule (no UICorner child to copy), so the shadow has its own
			local function radius(selector)
				for _, rule in Toaster.rules do
					if rule.selector == selector then
						return rule.properties.CornerRadius
					end
				end
				return nil
			end
			expect(radius(".ui-toast::UICorner")).to.be.ok()
			expect(radius(".ui-toast-shadow::UICorner")).to.equal(radius(".ui-toast::UICorner"))
		end)

		it("draws the PanelShadow token's shadow behind each toast, tagged with its kind", function()
			local id = app.toast.success("Saved")
			local panel = app:portal("toast"):FindFirstChild(id, true)
			local frame = panel.Parent
			task.wait()
			local shadow = frame:FindFirstChild("Shadow")
			expect(shadow.Visible).to.equal(true)
			expect(shadow.ZIndex < panel.ZIndex).to.equal(true)
			expect(frame:HasTag("ui-toast-frame-kind-success")).to.equal(true)
			app.toast("Saved", { id = id, kind = "error" })
			expect(frame:HasTag("ui-toast-frame-kind-error")).to.equal(true)
			expect(frame:HasTag("ui-toast-frame-kind-success")).to.equal(false)
		end)

		it("fills a kind with the theme's GradientToast<Kind>, and only a kind that has one", function()
			local saved = app.toast.success("Saved")
			local warned = app.toast.warning("Low ammo")
			local portal = app:portal("toast")
			Harness.flush()
			local panel = portal:FindFirstChild(saved, true)
			local gradient = panel:FindFirstChildWhichIsA("UIGradient")
			expect(gradient).to.be.ok()
			expect(gradient.Enabled).to.equal(true)
			-- A gradient tints the fill under it: the panel goes white so its colours show
			expect(Harness.colorEq(Harness.styled(panel, "BackgroundColor3"), Color3.new(1, 1, 1))).to.equal(
				true
			)
			local plain = portal:FindFirstChild(warned, true)
			local none = plain:FindFirstChildWhichIsA("UIGradient")
			expect(none == nil or none.Enabled == false).to.equal(true)
			expect(Harness.colorEq(Harness.styled(plain, "BackgroundColor3"), app.theme:resolve("Warning"))).to.equal(
				true
			)
		end)
	end)

	describe("while quiet", function()
		local app, cleanup, now
		beforeEach(function()
			app, cleanup = Harness.app({ theme = "light", namePrefix = "ToastQuiet_" })
			now = 0
			app.clock = function()
				return now
			end
		end)
		afterEach(function()
			cleanup()
		end)

		local function titles(): { string }
			local out = {}
			for _, toast in app.toast.list() do
				table.insert(out, toast.title)
			end
			return out
		end

		it("holds toasts and shows them when quiet ends", function()
			local release = app.quiet:push("tour")
			app.toast("Level up")
			expect(#app.toast.list()).to.equal(0)
			now = 10
			release()
			local list = app.toast.list()
			expect(#list).to.equal(1)
			expect(list[1].title).to.equal("Level up")
			expect(list[1].createdAt).to.equal(10)
		end)

		it("keeps only the newest visibleToasts when it lets them out", function()
			local release = app.quiet:push("tour")
			for i = 1, 5 do
				app.toast("t" .. i)
			end
			release()
			local shown = titles()
			expect(#shown).to.equal(3)
			expect(shown[1]).to.equal("t3")
			expect(shown[3]).to.equal("t5")
		end)

		it("replaces a held toast updated by id", function()
			local release = app.quiet:push("tour")
			local id = app.toast("Uploading")
			app.toast("Uploaded", { id = id })
			release()
			local shown = titles()
			expect(#shown).to.equal(1)
			expect(shown[1]).to.equal("Uploaded")
		end)

		it("drops toasts that ask to be dropped", function()
			local release = app.quiet:push("tour")
			app.toast("Next show soon", { quiet = "drop" })
			release()
			expect(#app.toast.list()).to.equal(0)
		end)

		it("shows toasts that ask to be shown", function()
			app.quiet:push("tour")
			app.toast.error("Disconnected", { quiet = "show" })
			expect(#app.toast.list()).to.equal(1)
		end)

		it("shows a toast on a channel the reason allows", function()
			app.quiet:push("tour", { allow = { "tour" } })
			app.toast("Nice!", { channel = "tour" })
			app.toast("Other")
			local shown = titles()
			expect(#shown).to.equal(1)
			expect(shown[1]).to.equal("Nice!")
		end)

		it("dismissing a held toast forgets it", function()
			local release = app.quiet:push("tour")
			local id = app.toast("Level up")
			app.toast.dismiss(id)
			release()
			expect(#app.toast.list()).to.equal(0)
		end)

		it("rejects an unknown quiet rule", function()
			expect(function()
				app.toast("x", { quiet = "later" })
			end).to.throw()
		end)
	end)
end
