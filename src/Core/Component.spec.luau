return function()
	local Component = require(script.Parent.Component)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	describe("create", function()
		it("builds an instance with properties, tags, attributes and children", function()
			local frame = Component.create("Frame", {
				Name = "Box",
				BackgroundTransparency = 1,
				Tags = { "ui-box" },
				Attributes = { kind = "test" },
			}, {
				Label = Component.create("TextLabel", { Text = "hi" }),
			})
			expect(frame.Name).to.equal("Box")
			expect(frame.BackgroundTransparency).to.equal(1)
			expect(frame:HasTag("ui-box")).to.equal(true)
			expect(frame:GetAttribute("kind")).to.equal("test")
			expect(frame.Label.Text).to.equal("hi")
			frame:Destroy()
		end)
	end)

	describe("setVariant", function()
		it("replaces the previous tag for the same key", function()
			local frame = Instance.new("Frame")
			Component.setVariant(frame, "ui-button", "variant", "default")
			expect(frame:HasTag("ui-button-variant-default")).to.equal(true)
			Component.setVariant(frame, "ui-button", "variant", "outline")
			expect(frame:HasTag("ui-button-variant-default")).to.equal(false)
			expect(frame:HasTag("ui-button-variant-outline")).to.equal(true)
			frame:Destroy()
		end)

		it("toggles boolean flag tags", function()
			local frame = Instance.new("Frame")
			Component.setFlag(frame, "ui-disabled", true)
			expect(frame:HasTag("ui-disabled")).to.equal(true)
			Component.setFlag(frame, "ui-disabled", false)
			expect(frame:HasTag("ui-disabled")).to.equal(false)
			frame:Destroy()
		end)
	end)

	describe("mount", function()
		local app, cleanup
		beforeEach(function()
			app, cleanup = Harness.app()
		end)
		afterEach(function()
			cleanup()
		end)

		local function mountThing(props)
			local renders = 0
			local handle = Component.mount({
				kind = "thing",
				props = props,
				defaults = { text = "", visible = true },
				rules = { { selector = ".ui-thing", properties = { BackgroundTransparency = 1 } } },
				render = function()
					return Component.create("TextLabel", { Tags = { "ui-thing" } })
				end,
				update = function(h, state)
					renders += 1
					h.Instance.Text = state.text
					h.Instance.Visible = state.visible
				end,
			})
			return handle, function()
				return renders
			end
		end

		it("stores props under ui.<id> and renders them", function()
			local handle = mountThing({ app = app, id = "greeting", text = "Hello" })
			expect(app.state:get("ui.greeting.text")).to.equal("Hello")
			expect(handle.Instance.Text).to.equal("Hello")
			handle:destroy()
		end)

		it("generates ids per kind when none is given", function()
			local a = mountThing({ app = app })
			local b = mountThing({ app = app })
			expect(a.id).to.equal("thing-1")
			expect(b.id).to.equal("thing-2")
			a:destroy()
			b:destroy()
		end)

		it("re-renders when app state changes", function()
			local handle = mountThing({ app = app, id = "g", text = "a" })
			app.state:set("ui.g.text", "b")
			expect(handle.Instance.Text).to.equal("b")
			handle:set({ visible = false })
			expect(handle.Instance.Visible).to.equal(false)
			expect(handle:get("visible")).to.equal(false)
			handle:destroy()
		end)

		it("lets pre-seeded app state win over props", function()
			app.state:set("ui.seeded", { text = "from app" })
			local handle = mountThing({ app = app, id = "seeded", text = "from props" })
			expect(handle.Instance.Text).to.equal("from app")
			handle:destroy()
		end)

		it("registers its rules on the theme once", function()
			local a = mountThing({ app = app })
			local b = mountThing({ app = app })
			expect(app.theme:hasRules("thing")).to.equal(true)
			a:destroy()
			b:destroy()
		end)

		it("cleans up instance and state on destroy", function()
			local handle = mountThing({ app = app, id = "gone" })
			local instance = handle.Instance
			handle:destroy()
			expect(instance.Parent).to.equal(nil)
			expect(app.state:get("ui.gone")).to.equal(nil)
		end)

		it("keeps state on destroy when persist is set", function()
			local handle = mountThing({ app = app, id = "kept", persist = true, text = "x" })
			handle:destroy()
			expect(app.state:get("ui.kept.text")).to.equal("x")
		end)

		it("replaces the engine selection ring and registers the handle", function()
			local handle = mountThing({ app = app, id = "sel" })
			expect(handle.Instance.SelectionImageObject).to.equal(app.selectionImage)
			expect(app:handle("sel")).to.equal(handle)
			handle:destroy()
			expect(app:handle("sel")).to.equal(nil)
		end)

		it("rejects ids with dots", function()
			expect(function()
				mountThing({ app = app, id = "a.b" })
			end).to.throw()
		end)
	end)

	describe("reactive props", function()
		local Reactive = require(script.Parent.Reactive)
		local app, cleanup
		beforeEach(function()
			app, cleanup = Harness.app()
		end)
		afterEach(function()
			cleanup()
		end)

		local function mountThing(props)
			local renders = 0
			local handle = Component.mount({
				kind = "thing",
				props = props,
				defaults = { text = "", visible = true },
				render = function()
					return Component.create("TextLabel", {})
				end,
				update = function(h, state)
					renders += 1
					h.Instance.Text = state.text
					h.Instance.Visible = state.visible
				end,
			})
			return handle, function()
				return renders
			end
		end

		it("follows a ref", function()
			local text = Reactive.ref("a")
			local handle = mountThing({ app = app, id = "r", text = text })
			expect(handle.Instance.Text).to.equal("a")
			text("b")
			expect(handle.Instance.Text).to.equal("b")
			expect(app.state:get("ui.r.text")).to.equal("b")
			handle:destroy()
		end)

		it("follows a computed and a plain getter", function()
			local count = Reactive.ref(1)
			local label = Reactive.computed(function()
				return `x{count()}`
			end)
			local hidden = Reactive.ref(false)
			local handle = mountThing({
				app = app,
				text = label,
				visible = function()
					return not hidden()
				end,
			})
			expect(handle.Instance.Text).to.equal("x1")
			count(2)
			hidden(true)
			expect(handle.Instance.Text).to.equal("x2")
			expect(handle.Instance.Visible).to.equal(false)
			handle:destroy()
		end)

		it("renders once on mount, then once per change", function()
			local text = Reactive.ref("a")
			local _, renders = mountThing({ app = app, text = text })
			expect(renders()).to.equal(1)
			text("b")
			expect(renders()).to.equal(2)
			text("b")
			expect(renders()).to.equal(2)
		end)

		it("lets the source win over pre-seeded state", function()
			app.state:set("ui.seed", { text = "from app" })
			local handle = mountThing({ app = app, id = "seed", text = Reactive.ref("from ref") })
			expect(handle.Instance.Text).to.equal("from ref")
			handle:destroy()
		end)

		it("writes state changes back to a ref", function()
			local text = Reactive.ref("a")
			local handle = mountThing({ app = app, id = "two", text = text })
			handle:set({ text = "from component" })
			expect(text()).to.equal("from component")
			app.state:set("ui.two.text", "from app")
			expect(text()).to.equal("from app")
			handle:destroy()
		end)

		it("writes back through a writable computed", function()
			local raw = Reactive.ref("a")
			local upper = Reactive.computed({
				get = function()
					return string.upper(raw())
				end,
				set = function(value)
					raw(string.lower(value))
				end,
			})
			local handle = mountThing({ app = app, text = upper })
			expect(handle.Instance.Text).to.equal("A")
			handle:set({ text = "Hi" })
			expect(raw()).to.equal("hi")
			expect(handle.Instance.Text).to.equal("HI")
			handle:destroy()
		end)

		it("keeps a read-only source one-way; its next change wins", function()
			local count = Reactive.ref(1)
			local handle = mountThing({
				app = app,
				text = function()
					return tostring(count())
				end,
			})
			handle:set({ text = "manual" })
			expect(handle.Instance.Text).to.equal("manual")
			count(2)
			expect(handle.Instance.Text).to.equal("2")
			handle:destroy()
		end)

		it("stops following after destroy", function()
			local text = Reactive.ref("a")
			local handle = mountThing({ app = app, id = "bye", text = text })
			local instance = handle.Instance
			handle:destroy()
			text("b")
			expect(instance.Text).to.equal("a")
			expect(app.state:get("ui.bye")).to.equal(nil)
		end)

		it("is destroyed when its owning scope stops", function()
			local scope = Reactive.effectScope()
			local handle = scope:run(function()
				return mountThing({ app = app })
			end)
			expect(handle.destroyed).to.equal(false)
			scope:stop()
			expect(handle.destroyed).to.equal(true)
		end)

		it("leaves callback props alone", function()
			local called = false
			local handle = Component.mount({
				kind = "thing",
				props = {
					app = app,
					onClick = function()
						called = true
					end,
				},
				defaults = { text = "" },
				render = function()
					return Component.create("TextLabel", {})
				end,
			})
			expect(handle:get("onClick")).to.equal(nil)
			expect(called).to.equal(false)
			handle:destroy()
		end)
	end)
end
