return function()
	local Component = require(script.Parent.Component)
	local Element = require(script.Parent.Element)
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
				render = function(h)
					local text = h:ref("text")
					return Element.new("TextLabel", {
						Text = function()
							renders += 1
							return text()
						end,
						Visible = h:ref("visible"),
						Tags = { "ui-thing" },
					})
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

		it("keeps a mounted component small", function()
			local Reactive = require(script.Parent.Reactive)
			local spec = {
				kind = "small",
				props = { app = app },
				defaults = { value = 0, label = "" },
				render = function(h)
					local value = h:ref("value")
					Reactive._effect(function()
						value()
					end)
					return Instance.new("Frame")
				end,
			}
			local least = math.huge
			for _ = 1, 5 do
				local scope = Reactive.effectScope(true)
				local before = gcinfo()
				scope:run(function()
					for _ = 1, 1000 do
						Component.mount(spec)
					end
				end)
				least = math.min(least, gcinfo() - before)
				scope:stop()
			end
			-- Under 2,400 bytes per component, everything included (gcinfo is in KB,
			-- 1,000 mounts): the handle, its scope and maid, its state table, one bound key.
			expect(least < 2400).to.equal(true)
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
				render = function(h)
					local text = h:ref("text")
					return Element.new("TextLabel", {
						Text = function()
							renders += 1
							return text()
						end,
						Visible = h:ref("visible"),
					})
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

		it("aliases a writable ref: every write to the key is a write to the ref, at once", function()
			local on = Reactive.ref("a")
			local handle = mountThing({ app = app, id = "alias", text = on })
			local seenByStore
			app.state:subscribe("ui.alias.text", function()
				seenByStore = on() -- the ref already holds the new value when subscribers run
			end)
			app.state:merge("ui.alias", { text = "merged" })
			expect(on()).to.equal("merged")
			expect(seenByStore).to.equal("merged")
			app.state:set("ui.alias", { text = "replaced", visible = true })
			expect(on()).to.equal("replaced")
			handle:set("text", "key form")
			expect(on()).to.equal("key form")
			on("from ref")
			expect(handle:get("text")).to.equal("from ref")
			expect(handle.Instance.Text).to.equal("from ref")
			handle:destroy()
		end)

		it("shares one ref between many components without ping-pong", function()
			local on = Reactive.ref("x")
			local a, rendersA = mountThing({ app = app, text = on })
			local b, rendersB = mountThing({ app = app, text = on })
			a:set("text", "y")
			expect(on()).to.equal("y")
			expect(b.Instance.Text).to.equal("y")
			expect(rendersA()).to.equal(2)
			expect(rendersB()).to.equal(2)
			a:destroy()
			b:destroy()
		end)

		it("lets an aliased ref outlive the component, unbound", function()
			local on = Reactive.ref("a")
			local handle = mountThing({ app = app, id = "owner", persist = true, text = on })
			handle:destroy()
			on("after")
			expect(app.state:get("ui.owner.text")).to.equal("a")
			app.state:set("ui.owner.text", "store only")
			expect(on()).to.equal("after")
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

	describe("declarative render", function()
		local Reactive = require(script.Parent.Reactive)
		local app, cleanup
		beforeEach(function()
			app, cleanup = Harness.app()
		end)
		afterEach(function()
			cleanup()
		end)

		local function mountBound(props, log)
			return Component.mount({
				kind = "bound",
				props = props,
				defaults = { text = "", count = 0 },
				render = function(h)
					local count = h:ref("count")
					Reactive.watch(count, function(new, old)
						table.insert(log, `{old}>{new}`)
					end)
					return Element.new("TextLabel", {
						Text = h:ref("text"),
						Tags = {
							["ui-many"] = function()
								return count() > 1
							end,
						},
					})
				end,
			})
		end

		it("binds the instance to state keys through h:ref", function()
			local log = {}
			local handle = mountBound({ app = app, id = "b", text = "a" }, log)
			expect(handle.Instance.Text).to.equal("a")
			app.state:set("ui.b.text", "b")
			expect(handle.Instance.Text).to.equal("b")
			handle:set("count", 2)
			expect(handle.Instance:HasTag("ui-many")).to.equal(true)
			expect(table.concat(log, ",")).to.equal("0>2")
			handle:destroy()
		end)

		it("writes the store through h:ref, reaching bound refs", function()
			local text = Reactive.ref("a")
			local handle = mountBound({ app = app, text = text }, {})
			handle:ref("text")("from ref write")
			expect(text()).to.equal("from ref write")
			expect(handle:get("text")).to.equal("from ref write")
			expect(handle:ref("text")).to.equal(handle:ref("text"))
			handle:destroy()
		end)

		it("owns everything render creates", function()
			local log = {}
			local count = Reactive.ref(1)
			local handle = mountBound({ app = app, count = count }, log)
			local instance = handle.Instance
			count(3)
			expect(table.concat(log, ",")).to.equal("1>3")
			handle:destroy()
			count(4)
			expect(#log).to.equal(1)
			expect(instance.Parent).to.equal(nil)
		end)

		it("cleans up when render errors", function()
			local effectRuns = 0
			local source = Reactive.ref(0)
			expect(function()
				Component.mount({
					kind = "broken",
					props = { app = app },
					render = function()
						Reactive.watchEffect(function()
							source()
							effectRuns += 1
						end)
						error("nope")
					end,
				})
			end).to.throw()
			source(1)
			expect(effectRuns).to.equal(1)
		end)
	end)
end
