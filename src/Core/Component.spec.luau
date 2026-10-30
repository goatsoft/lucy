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
				render = function(h)
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
end
