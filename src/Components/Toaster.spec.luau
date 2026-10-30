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
			expect(portal:FindFirstChild("toast-1", true).Visible).to.equal(false)
			expect(portal:FindFirstChild("toast-5", true).Visible).to.equal(true)
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

		it("colours the accent by kind", function()
			local id = app.toast.error("Nope")
			Harness.flush()
			local accent = app:portal("toast"):FindFirstChild(id, true).Row.Accent
			expect(
				Harness.colorEq(Harness.styled(accent, "BackgroundColor3"), app.theme:resolve("Destructive"))
			).to.equal(true)
		end)
	end)
end
