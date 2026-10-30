return function()
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Preview = require(script.Parent.Preview)
	local Reactive = require(script.Parent.Reactive)
	local Element = require(script.Parent.Element)
	local Context = require(script.Parent.Context)
	local Button = require(script.Parent.Parent.Components.Button)
	local Switch = require(script.Parent.Parent.Components.Switch)

	local parent = Harness.guiParent()
	local mounted

	local function mount(story, options)
		local opts = table.clone(options or {})
		opts.parent = opts.parent or parent
		opts.device = opts.device or "desktop"
		mounted = Preview.mount(story, opts)
		return mounted
	end

	afterEach(function()
		if mounted then
			mounted:destroy()
			mounted = nil
		end
		Preview.clear()
	end)

	describe("controlsOf", function()
		it("infers kinds and defaults, sorted by name", function()
			local controls = Preview.controlsOf({
				controls = {
					text = "Go",
					disabled = false,
					variant = { "default", "outline" },
					value = { min = 0, max = 100, default = 40 },
					count = 3,
					size = { options = { "sm", "md", "lg" }, default = "md" },
				},
			})
			local byName = {}
			local names = {}
			for _, control in controls do
				byName[control.name] = control
				table.insert(names, control.name)
			end
			expect(table.concat(names, ",")).to.equal("count,disabled,size,text,value,variant")
			expect(byName.text.kind).to.equal("string")
			expect(byName.disabled.kind).to.equal("boolean")
			expect(byName.variant.kind).to.equal("choice")
			expect(byName.variant.default).to.equal("default")
			expect(byName.size.default).to.equal("md")
			expect(#byName.size.options).to.equal(3)
			expect(byName.value.kind).to.equal("number")
			expect(byName.value.default).to.equal(40)
			expect(byName.value.max).to.equal(100)
			expect(byName.count.kind).to.equal("number")
			expect(byName.count.default).to.equal(3)
		end)

		it("returns an empty list for a story without controls", function()
			expect(#Preview.controlsOf({ render = function() end })).to.equal(0)
		end)

		it("rejects a choice default that is not an option", function()
			expect(function()
				Preview.controlsOf({ controls = { size = { options = { "sm" }, default = "xl" } } })
			end).to.throw()
		end)
	end)

	describe("mount", function()
		it("renders what the story returns into the target", function()
			local m = mount({
				render = function()
					return Element.new("Frame")({ Name = "Hello" })
				end,
			})
			expect(m.target:FindFirstChild("Hello")).to.be.ok()
			expect(m.gui:IsA("ScreenGui")).to.equal(true)
			expect(m.gui.Parent).to.equal(parent)
			expect(m.error).to.equal(nil)
		end)

		it("gives render the app, the target and controls as refs", function()
			local seen
			mount({
				controls = { text = "Go" },
				render = function(ctx)
					seen = ctx
				end,
			})
			expect(seen.app).to.equal(mounted.app)
			expect(seen.target).to.equal(mounted.target)
			expect(Reactive.isWritable(seen.controls.text)).to.equal(true)
			expect(seen.controls.text()).to.equal("Go")
			expect(seen.Lucy.Preview).to.equal(Preview)
		end)

		it("makes the story app current while mounted and restores the previous one", function()
			local before = Context.getCurrent()
			local during
			mount({
				render = function()
					during = Context.getCurrent()
				end,
			})
			expect(during).to.equal(mounted.app)
			mounted:destroy()
			mounted = nil
			expect(Context.getCurrent()).to.equal(before)
		end)

		it("drives components through control refs", function()
			local button
			local m = mount({
				controls = { text = "One", disabled = false },
				render = function(ctx)
					button = Button.new({ text = ctx.controls.text, disabled = ctx.controls.disabled })
					return button
				end,
			})
			expect(button.Instance.Parent).to.equal(m.target)
			m:set("text", "Two")
			m:set("disabled", true)
			expect(button:get("text")).to.equal("Two")
			expect(button:get("disabled")).to.equal(true)
		end)

		it("writes component changes back to writable controls", function()
			local switch
			local m = mount({
				controls = { checked = false },
				render = function(ctx)
					switch = Switch.new({ checked = ctx.controls.checked })
					return switch
				end,
			})
			switch:toggle()
			expect(m.controls.checked()).to.equal(true)
			expect(m:values().checked).to.equal(true)
		end)

		it("keeps reads made by render out of an enclosing effect", function()
			local runs = 0
			local stop = Reactive.watchEffect(function()
				runs += 1
				Reactive.onCleanup(function()
					if mounted then
						mounted:destroy()
					end
				end)
				mount({
					controls = { text = "a" },
					render = function(ctx)
						ctx.controls.text()
					end,
				})
			end)
			mounted:set("text", "b")
			expect(runs).to.equal(1)
			stop()
		end)

		it("takes initial control values from options", function()
			local m = mount({ controls = { text = "Default" }, render = function() end }, {
				controls = { text = "Override" },
			})
			expect(m.controls.text()).to.equal("Override")
		end)

		it("uses the requested theme and device", function()
			local m = mount({ render = function() end }, { theme = "light", device = "console" })
			expect(m.app.theme:get()).to.equal("light")
			expect(m.app.state:get("input.device")).to.equal("console")
			expect(m.app.theme:getDensity()).to.equal("tv")
		end)

		it("paints the canvas with the theme background unless asked not to", function()
			local m = mount({ render = function() end }, { theme = "dark" })
			Harness.flush()
			expect(Harness.styled(m.canvas, "BackgroundTransparency")).to.equal(0)
			expect(
				Harness.colorEq(
					Harness.styled(m.canvas, "BackgroundColor3"),
					m.app.theme:resolve("Background")
				)
			).to.equal(true)
			m:destroy()
			local clear = mount({ render = function() end }, { background = false })
			Harness.flush()
			expect(Harness.styled(clear.canvas, "BackgroundTransparency")).to.equal(1)
		end)

		it("fills the gui for fullscreen stories and centres otherwise", function()
			local centred = mount({ render = function() end })
			expect(centred.target.AnchorPoint).to.equal(Vector2.new(0.5, 0.5))
			centred:destroy()
			local full = mount({ layout = "fullscreen", render = function() end })
			expect(full.target.Size).to.equal(UDim2.fromScale(1, 1))
		end)

		it("catches render errors and shows them", function()
			local m = mount({
				render = function()
					error("boom")
				end,
			})
			expect(m.error).to.be.ok()
			expect((string.find(m.error, "boom", 1, true))).to.be.ok()
			local label = m.gui:FindFirstChild("PreviewError", true)
			expect(label).to.be.ok()
		end)

		it("destroys everything it created on destroy", function()
			local element, button, cleaned
			local m = mount({
				render = function()
					Reactive.onCleanup(function()
						cleaned = true
					end)
					element = Element.new("Frame")({})
					button = Button.new({ text = "x" })
					return { element, button }
				end,
			})
			local gui, app = m.gui, m.app
			m:destroy()
			mounted = nil
			expect(cleaned).to.equal(true)
			expect(element.Parent).to.equal(nil)
			expect(button.destroyed).to.equal(true)
			expect(gui.Parent).to.equal(nil)
			expect(app.destroyed).to.equal(true)
		end)

		it("lets scene stories drive the story app's scenes", function()
			local m = mount({
				layout = "fullscreen",
				render = function(ctx)
					ctx.app.scenes:register("Title", {
						build = function(scene)
							Element.new("Frame")({ Name = "TitleRoot", Parent = scene.gui })
						end,
					})
					ctx.app.scenes:goTo("Title")
				end,
			})
			local scene = m.app.scenes:get("Title")
			expect(scene.gui.Enabled).to.equal(true)
			expect(scene.gui:FindFirstChild("TitleRoot")).to.be.ok()
			local gui = scene.gui
			m:destroy()
			mounted = nil
			expect(gui.Parent).to.equal(nil)
		end)
	end)

	describe("show and clear", function()
		it("replaces the shown story and clears it", function()
			local first = Preview.show({ title = "A", render = function() end }, { parent = parent })
			local second = Preview.show({ title = "B", render = function() end }, { parent = parent })
			expect(first.destroyed).to.equal(true)
			expect(Preview.current()).to.equal(second)
			Preview.clear()
			expect(second.destroyed).to.equal(true)
			expect(Preview.current()).to.equal(nil)
		end)
	end)

	describe("find", function()
		it("collects *.story modules under a root, titled by module name", function()
			local root = Instance.new("Folder")
			local ok = pcall(function()
				local module = Instance.new("ModuleScript")
				module.Name = "Thing.story"
				module.Source = "return { group = 'Tests', render = function() end }"
				module.Parent = root
				local other = Instance.new("ModuleScript")
				other.Name = "Helper"
				other.Source = "return {}"
				other.Parent = root
			end)
			if not ok then
				-- Setting Source needs plugin security (command bar / MCP); skip elsewhere.
				root:Destroy()
				return
			end
			local stories = Preview.find(root)
			root:Destroy()
			expect(#stories).to.equal(1)
			expect(stories[1].id).to.equal("Thing")
			expect(stories[1].title).to.equal("Thing")
			expect(stories[1].group).to.equal("Tests")
		end)
	end)
end
