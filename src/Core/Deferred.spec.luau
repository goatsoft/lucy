return function()
	local Deferred = require(script.Parent.Deferred)
	local Component = require(script.Parent.Component)
	local Reactive = require(script.Parent.Reactive)
	local Button = require(script.Parent.Parent.Components.Button)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	-- A bare component with one slot holding a layout of its own
	local function thing(): (any, Frame, UIListLayout)
		local handle = Component.mount({
			kind = "thing",
			defaults = { open = false },
			render = function()
				return Instance.new("Frame")
			end,
		}, { app = app, Parent = gui })
		local slot = Instance.new("Frame")
		slot.Name = "Slot"
		local layout = Instance.new("UIListLayout")
		layout.Parent = slot
		slot.Parent = handle.Instance
		return handle, slot, layout
	end

	-- A part whose build puts one Button in the slot. Returns it, how often it built, the buttons.
	local function withButton(handle: any, slot: Frame, keep: boolean?): (any, { number }, { any })
		local count, buttons = { 0 }, {}
		local part = Deferred.new(handle, {
			slots = { slot },
			keep = keep,
			build = function()
				count[1] += 1
				table.insert(buttons, Button.new({ app = app, text = "Buy", Parent = slot }))
			end,
		})
		return part, count, buttons
	end

	describe("mode", function()
		it("builds on open and keeps by default", function()
			local deferred, keep = Deferred.mode({}, "Tabs")
			expect(deferred).to.equal(true)
			expect(keep).to.equal(true)
		end)

		it("builds at once with mount = now", function()
			local deferred, keep = Deferred.mode({ mount = "now" }, "Tabs")
			expect(deferred).to.equal(false)
			expect(keep).to.equal(true)
		end)

		it("takes keep = false with mount = open", function()
			local deferred, keep = Deferred.mode({ mount = "open", keep = false }, "Tabs")
			expect(deferred).to.equal(true)
			expect(keep).to.equal(false)
		end)

		it("refuses an unknown mount, and keep with mount = now", function()
			expect(function()
				Deferred.mode({ mount = "later" }, "Tabs")
			end).to.throw("mount")
			expect(function()
				Deferred.mode({ mount = "now", keep = false }, "Tabs")
			end).to.throw("keep")
		end)
	end)

	describe("build", function()
		it("builds once, when asked", function()
			local handle, slot = thing()
			local part, count = withButton(handle, slot)
			expect(count[1]).to.equal(0)
			expect(part.built()).to.equal(false)
			expect(part:build()).to.equal(true)
			expect(part.built()).to.equal(true)
			expect(part:build()).to.equal(false)
			expect(count[1]).to.equal(1)
		end)

		it("ends what it built with the component", function()
			local handle, slot = thing()
			local part, _, buttons = withButton(handle, slot)
			part:build()
			handle:destroy()
			expect(buttons[1].destroyed).to.equal(true)
		end)

		it("keeps what it built when the watcher that asked runs again", function()
			local handle, slot = thing()
			local part, _, buttons = withButton(handle, slot)
			local open = Reactive.ref(false)
			local scope = Reactive.effectScope(true)
			scope:run(function()
				Reactive.watch(open, function(isOpen)
					if isOpen then
						part:build()
					end
				end)
			end)
			open(true)
			open(false)
			open(true)
			expect(buttons[1].destroyed).to.equal(false)
			scope:stop()
			expect(buttons[1].destroyed).to.equal(false)
		end)

		it("does not subscribe the caller to what the builder reads", function()
			local handle, slot = thing()
			local read = Reactive.ref(1)
			local part = Deferred.new(handle, {
				slots = { slot },
				build = function()
					read()
				end,
			})
			local runs = 0
			local stop = Reactive.watchEffect(function()
				runs += 1
				part:build()
			end)
			read(2)
			expect(runs).to.equal(1)
			stop()
		end)

		it("claims the selection ring of what it built", function()
			local handle, slot = thing()
			local made: TextButton
			local part = Deferred.new(handle, {
				slots = { slot },
				build = function()
					made = Instance.new("TextButton")
					made.Parent = slot
				end,
			})
			part:build()
			expect(made.SelectionImageObject).to.equal(app.selectionImage)
		end)

		it("leaves nothing half built when the builder throws, and can build again", function()
			local handle, slot, layout = thing()
			local fail = true
			local button: any
			local part = Deferred.new(handle, {
				slots = { slot },
				build = function()
					button = Button.new({ app = app, Parent = slot })
					if fail then
						error("no songs", 0)
					end
				end,
			})
			expect(function()
				part:build()
			end).to.throw("no songs")
			expect(part.built()).to.equal(false)
			expect(button.destroyed).to.equal(true)
			expect(#slot:GetChildren()).to.equal(1)
			expect(layout.Parent).to.equal(slot)
			fail = false
			expect(part:build()).to.equal(true)
			expect(button.destroyed).to.equal(false)
		end)

		it("does nothing once the component is destroyed", function()
			local handle, slot = thing()
			local part, count = withButton(handle, slot)
			handle:destroy()
			expect(part:build()).to.equal(false)
			expect(count[1]).to.equal(0)
		end)
	end)

	describe("remove", function()
		it("takes away what was built and leaves what the slot had", function()
			local handle, slot, layout = thing()
			local part, count, buttons = withButton(handle, slot)
			local plain = Instance.new("Frame")
			local both = Deferred.new(handle, {
				slots = { slot },
				build = function()
					plain.Parent = slot
				end,
			})
			part:build()
			part:remove()
			expect(part.built()).to.equal(false)
			expect(buttons[1].destroyed).to.equal(true)
			expect(layout.Parent).to.equal(slot)
			expect(#slot:GetChildren()).to.equal(1)
			-- built again on the next ask, new
			expect(part:build()).to.equal(true)
			expect(count[1]).to.equal(2)
			expect(buttons[2].destroyed).to.equal(false)
			-- a plain instance goes too, and another part's content in the same slot stays
			both:build()
			both:remove()
			expect(plain.Parent).to.equal(nil)
			expect(buttons[2].destroyed).to.equal(false)
		end)

		it("does nothing before a build", function()
			local handle, slot, layout = thing()
			local part = withButton(handle, slot)
			part:remove()
			expect(layout.Parent).to.equal(slot)
		end)
	end)

	describe("place", function()
		it("calls a builder with the slot and keeps what it parents there", function()
			local slot = Instance.new("Frame")
			local got
			Deferred.place(slot, function(into)
				got = into
				local label = Instance.new("TextLabel")
				label.Name = "Made"
				label.Parent = into
			end)
			expect(got).to.equal(slot)
			expect(slot:FindFirstChild("Made")).to.be.ok()
		end)

		it("adopts a returned instance, handle or list of them", function()
			local slot = Instance.new("Frame")
			local label = Instance.new("TextLabel")
			Deferred.place(slot, function()
				return label
			end)
			expect(label.Parent).to.equal(slot)
			expect(label.LayoutOrder).to.equal(1)
			local button = Button.new({ app = app })
			Deferred.place(slot, function()
				return button
			end)
			expect(button.Instance.Parent).to.equal(slot)
			local first, second = Instance.new("Frame"), Instance.new("Frame")
			Deferred.place(slot, function()
				return { first, second }
			end)
			expect(first.Parent).to.equal(slot)
			expect(second.LayoutOrder).to.equal(2)
		end)

		it("leaves a returned instance where the builder put it inside the slot", function()
			local slot = Instance.new("Frame")
			local row = Instance.new("Frame")
			row.Parent = slot
			local label = Instance.new("TextLabel")
			Deferred.place(slot, function()
				label.Parent = row
				return label
			end)
			expect(label.Parent).to.equal(row)
		end)
	end)

	describe("follow", function()
		it("builds on open, and shown is true only once the content is there", function()
			local handle, slot = thing()
			local part = withButton(handle, slot)
			local open = handle:ref("open")
			local shown = part:follow(open)
			local seen = {}
			local stop = Reactive.watchEffect(function()
				if shown() then
					table.insert(seen, #slot:GetChildren())
				end
			end)
			expect(shown()).to.equal(false)
			open(true)
			expect(shown()).to.equal(true)
			expect(#seen).to.equal(1)
			expect(seen[1]).to.equal(2) -- the layout and the button
			open(false)
			expect(shown()).to.equal(false)
			expect(part.built()).to.equal(true) -- kept
			stop()
		end)

		it("writes open through shown", function()
			local handle, slot = thing()
			local part = withButton(handle, slot)
			local open = handle:ref("open")
			local shown = part:follow(open)
			open(true)
			shown(false)
			expect(handle:get("open")).to.equal(false)
			expect(Reactive.isWritable(shown)).to.equal(true)
		end)

		it("closes again and reports when the builder throws, and can open later", function()
			local handle, slot = thing()
			local fail = true
			local part = Deferred.new(handle, {
				slots = { slot },
				build = function()
					if fail then
						error("no songs", 0)
					end
				end,
			})
			local reported = {}
			local report = Deferred.report
			Deferred.report = function(err)
				table.insert(reported, tostring(err))
			end
			local open = handle:ref("open")
			local shown = part:follow(open)
			open(true)
			Deferred.report = report
			expect(handle:get("open")).to.equal(false)
			expect(shown()).to.equal(false)
			expect(#reported).to.equal(1)
			expect((string.find(reported[1], "no songs", 1, true))).to.be.ok()
			fail = false
			open(true)
			expect(shown()).to.equal(true)
		end)

		it("builds what is open from the start when started", function()
			local handle, slot = thing()
			local part, count = withButton(handle, slot)
			local open = handle:ref("open")
			open(true)
			local shown = part:follow(open)
			expect(shown()).to.equal(false)
			part:start(open)
			expect(count[1]).to.equal(1)
			expect(shown()).to.equal(true)
		end)

		it("removes on close with keep = false, once it is no longer visible", function()
			local handle, slot = thing()
			local part, count, buttons = withButton(handle, slot, false)
			local open = handle:ref("open")
			local visible = Reactive.ref(false)
			part:follow(open, { visible = visible })
			visible(true)
			open(true)
			open(false) -- sliding out: still visible
			expect(part.built()).to.equal(true)
			visible(false)
			expect(part.built()).to.equal(false)
			expect(buttons[1].destroyed).to.equal(true)
			-- opened again before the slide ends: kept
			visible(true)
			open(true)
			expect(count[1]).to.equal(2)
			open(false)
			open(true)
			visible(false)
			visible(true)
			expect(part.built()).to.equal(true)
			expect(count[1]).to.equal(2)
		end)

		it("removes on close with keep = false and nothing to wait for", function()
			local handle, slot = thing()
			local part = withButton(handle, slot, false)
			local open = handle:ref("open")
			part:follow(open)
			open(true)
			open(false)
			expect(part.built()).to.equal(false)
		end)
	end)
end
