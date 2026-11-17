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
		it("builds on first show and keeps by default", function()
			local mount, keep = Deferred.mode({}, "Tabs")
			expect(mount).to.equal("shown")
			expect(keep).to.equal(true)
		end)

		it("builds at once with mount = immediate", function()
			local mount, keep = Deferred.mode({ mount = "immediate" }, "Tabs")
			expect(mount).to.equal("immediate")
			expect(keep).to.equal(true)
		end)

		it("takes keep = false with mount = shown", function()
			local mount, keep = Deferred.mode({ mount = "shown", keep = false }, "Tabs")
			expect(mount).to.equal("shown")
			expect(keep).to.equal(false)
		end)

		it("refuses an unknown mount, and keep with mount = immediate", function()
			expect(function()
				Deferred.mode({ mount = "later" }, "Tabs")
			end).to.throw("mount")
			expect(function()
				Deferred.mode({ mount = "immediate", keep = false }, "Tabs")
			end).to.throw("keep")
			-- the old names
			expect(function()
				Deferred.mode({ mount = "open" }, "Tabs")
			end).to.throw("mount")
		end)

		it("takes only the values a component allows, and its own default", function()
			local allowed = { "immediate", "intersect" }
			expect((Deferred.mode({}, "Stack", allowed, "immediate"))).to.equal("immediate")
			expect((Deferred.mode({ mount = "intersect" }, "Stack", allowed, "immediate"))).to.equal(
				"intersect"
			)
			expect(function()
				Deferred.mode({ mount = "shown" }, "Stack", allowed, "immediate")
			end).to.throw("mount")
			expect(function()
				Deferred.mode({ mount = "intersect" }, "Tabs")
			end).to.throw("mount")
			expect(function()
				Deferred.mode({ mount = "intersect", keep = false }, "Stack", allowed, "immediate")
			end).to.throw("keep")
		end)
	end)

	describe("intersect", function()
		-- A 400 px tall scroll area holding `count` slots of 300 px, one under the other, each with
		-- a part that puts a Button in it; slot `hidden` starts hidden. Returns the scroller, the
		-- slots, the parts and the counts.
		local function list(
			count: number,
			parent: Instance?,
			hidden: number?
		): (ScrollingFrame, { Frame }, { any }, { number })
			local scroller = Instance.new("ScrollingFrame")
			scroller.Size = UDim2.fromOffset(300, 400)
			scroller.CanvasSize = UDim2.fromOffset(0, 0)
			scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
			scroller.ScrollingDirection = Enum.ScrollingDirection.Y
			local handle = Component.mount({
				kind = "thing",
				render = function()
					local frame = Instance.new("Frame")
					frame.Size = UDim2.fromScale(1, 0)
					frame.AutomaticSize = Enum.AutomaticSize.Y
					local layout = Instance.new("UIListLayout")
					layout.SortOrder = Enum.SortOrder.LayoutOrder
					layout.Parent = frame
					return frame
				end,
			}, { app = app, Parent = scroller })
			local slots, parts, counts = {}, {}, {}
			for i = 1, count do
				local slot = Instance.new("Frame")
				slot.Name = `Slot{i}`
				slot.LayoutOrder = i
				slot.Size = UDim2.new(1, 0, 0, 300)
				slot.Visible = i ~= hidden
				slot.Parent = handle.Instance
				slots[i] = slot
				counts[i] = 0
				parts[i] = Deferred.new(handle, {
					name = i,
					slots = { slot },
					build = function()
						counts[i] += 1
						Button.new({ app = app, Parent = slot })
					end,
				})
			end
			handle.scope:run(Deferred.intersect, parts)
			scroller.Parent = parent or gui
			return scroller, slots, parts, counts
		end

		local function built(parts: { any }): string
			local out = {}
			for i, part in parts do
				if part.built() then
					table.insert(out, tostring(i))
				end
			end
			return table.concat(out, ",")
		end

		it("builds what is within a view of the visible part, and more as it is scrolled to", function()
			if not Harness.laysOutLive() then
				return
			end
			local scroller, _, parts, counts = list(8)
			-- 400 px showing and 400 px ahead: the slots that start before 800 px
			expect(Harness.waitFor(function()
				return built(parts) == "1,2,3"
			end)).to.equal(true)
			scroller.CanvasPosition = Vector2.new(0, 600)
			expect(Harness.waitFor(function()
				return built(parts) == "1,2,3,4,5"
			end)).to.equal(true)
			scroller.CanvasPosition = Vector2.new(0, 0)
			task.wait()
			task.wait()
			expect(built(parts)).to.equal("1,2,3,4,5")
			expect(counts[1]).to.equal(1)
			expect(counts[6]).to.equal(0)
		end)

		it("leaves a hidden slot alone until it shows", function()
			if not Harness.laysOutLive() then
				return
			end
			local _, slots, parts = list(2, nil, 1)
			expect(Harness.waitFor(function()
				return built(parts) == "2"
			end)).to.equal(true)
			slots[1].Visible = true
			expect(Harness.waitFor(function()
				return built(parts) == "1,2"
			end)).to.equal(true)
		end)

		it("waits for what hides it from above, a tab not picked", function()
			if not Harness.laysOutLive() then
				return
			end
			local panel = Instance.new("Frame")
			panel.Size = UDim2.fromOffset(300, 400)
			panel.Visible = false
			panel.Parent = gui
			local _, _, parts = list(4, panel)
			for _ = 1, 4 do
				task.wait()
			end
			expect(built(parts)).to.equal("")
			panel.Visible = true
			expect(Harness.waitFor(function()
				return built(parts) == "1,2,3"
			end)).to.equal(true)
		end)

		it("builds whatever shows when no scroll area is around it", function()
			if not Harness.laysOutLive() then
				return
			end
			local handle, slot = thing()
			slot.Size = UDim2.fromOffset(100, 50)
			local part = withButton(handle, slot)
			handle.scope:run(Deferred.intersect, { part })
			expect(Harness.waitFor(function()
				return part.built()
			end)).to.equal(true)
		end)

		it("stops looking with the component", function()
			if not Harness.laysOutLive() then
				return
			end
			local scroller, _, parts, counts = list(8)
			Harness.waitFor(function()
				return built(parts) == "1,2,3"
			end)
			parts[1].handle:destroy()
			scroller.CanvasPosition = Vector2.new(0, 600)
			task.wait()
			task.wait()
			expect(counts[5]).to.equal(0)
		end)
	end)

	describe("prebuild", function()
		it("builds one handle a frame, skipping what is destroyed, and says how far it is", function()
			local order = {}
			local function fake(name: string, destroyed: boolean?): any
				return {
					destroyed = destroyed == true,
					build = function()
						table.insert(order, name)
					end,
				}
			end
			local job = Deferred.prebuild({ fake("inventory"), fake("gone", true), fake("settings"), {} })
			expect(#order).to.equal(1)
			expect(job.done()).to.equal(false)
			expect(Harness.waitFor(job.done)).to.equal(true)
			expect(table.concat(order, ",")).to.equal("inventory,settings")
			expect(job.progress()).to.equal(1)
		end)

		it("is done at once with nothing to build, and reports a builder that throws", function()
			expect(Deferred.prebuild({}).done()).to.equal(true)
			local reported = 0
			local report = Deferred.report
			Deferred.report = function()
				reported += 1
			end
			local job = Deferred.prebuild({
				{
					build = function()
						error("no songs", 0)
					end,
				},
			})
			Deferred.report = report
			expect(job.done()).to.equal(true)
			expect(reported).to.equal(1)
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
