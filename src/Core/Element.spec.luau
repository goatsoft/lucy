return function()
	local Reactive = require(script.Parent.Reactive)
	local Element = require(script.Parent.Element)
	local ref, computed = Reactive.ref, Reactive.computed
	local new, hydrate = Element.new, Element.hydrate

	local function scoped(fn)
		local scope = Reactive.effectScope(true)
		local result = scope:run(fn)
		return result, scope
	end

	describe("new", function()
		it("creates an instance with properties and a parent set last", function()
			local holder = Instance.new("Folder")
			local frame = new("Frame")({
				Name = "Card",
				BackgroundTransparency = 0.5,
				Parent = holder,
			})
			expect(frame.ClassName).to.equal("Frame")
			expect(frame.Name).to.equal("Card")
			expect(frame.BackgroundTransparency).to.equal(0.5)
			expect(frame.Parent).to.equal(holder)
			holder:Destroy()
		end)

		it("also takes props directly: new(class, props)", function()
			local label = new("TextLabel", { Text = "Hi" })
			expect(label.Text).to.equal("Hi")
			label:Destroy()
		end)

		it("binds refs, computeds and getters to properties", function()
			local count = ref(1)
			local label = new("TextLabel")({
				Text = computed(function()
					return `Count {count()}`
				end),
				Visible = function()
					return count() < 3
				end,
			})
			expect(label.Text).to.equal("Count 1")
			count(3)
			expect(label.Text).to.equal("Count 3")
			expect(label.Visible).to.equal(false)
			label:Destroy()
		end)

		it("names the property in errors", function()
			local ok, err = pcall(function()
				new("Frame")({ NotAProperty = 1 })
			end)
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "Frame.NotAProperty", 1, true) ~= nil).to.equal(true)
		end)

		it("stops its bindings when the instance is destroyed", function()
			local text = ref("a")
			local label = new("TextLabel")({ Text = text })
			label:Destroy()
			task.wait()
			text("b")
			expect(label.Text).to.equal("a")
		end)

		it("destroys what it created when the owning scope stops", function()
			local frame, scope = scoped(function()
				return new("Frame")({ Parent = workspace })
			end)
			scope:stop()
			expect(frame.Parent).to.equal(nil)
		end)
	end)

	describe("tags and attributes", function()
		it("adds static tags and toggles keyed tags by a boolean", function()
			local active = ref(false)
			local frame = new("Frame")({
				Tags = { "card", ["card-active"] = active, ["card-big"] = true },
			})
			expect(frame:HasTag("card")).to.equal(true)
			expect(frame:HasTag("card-big")).to.equal(true)
			expect(frame:HasTag("card-active")).to.equal(false)
			active(true)
			expect(frame:HasTag("card-active")).to.equal(true)
			frame:Destroy()
		end)

		it("accepts a getter for the whole tag set and diffs it", function()
			local variant = ref("primary")
			local frame = new("Frame")({
				Tags = function()
					return { "btn", "btn-" .. variant() }
				end,
			})
			expect(frame:HasTag("btn-primary")).to.equal(true)
			variant("ghost")
			expect(frame:HasTag("btn-primary")).to.equal(false)
			expect(frame:HasTag("btn-ghost")).to.equal(true)
			expect(frame:HasTag("btn")).to.equal(true)
			frame:Destroy()
		end)

		it("binds attributes", function()
			local hp = ref(10)
			local frame = new("Frame")({ Attributes = { Health = hp, Kind = "boss" } })
			expect(frame:GetAttribute("Health")).to.equal(10)
			expect(frame:GetAttribute("Kind")).to.equal("boss")
			hp(5)
			expect(frame:GetAttribute("Health")).to.equal(5)
			frame:Destroy()
		end)
	end)

	describe("events and two-way binding", function()
		it("connects events with Element.on", function()
			local fired = 0
			local bindable = new("BindableEvent")({
				[Element.on("Event")] = function(amount)
					fired += amount
				end,
			})
			bindable:Fire(2)
			task.wait()
			expect(fired).to.equal(2)
			bindable:Destroy()
		end)

		it("calls back on property changes with Element.changed", function()
			local seen
			local box = new("TextBox")({
				[Element.changed("Text")] = function(text)
					seen = text
				end,
			})
			box.Text = "hello"
			task.wait()
			expect(seen).to.equal("hello")
			box:Destroy()
		end)

		it("writes a property into a ref with Element.out", function()
			local size = ref(nil :: any)
			local frame = new("Frame")({ Size = UDim2.fromOffset(10, 10), [Element.out("Size")] = size })
			expect(size()).to.equal(UDim2.fromOffset(10, 10))
			frame.Size = UDim2.fromOffset(20, 20)
			task.wait()
			expect(size()).to.equal(UDim2.fromOffset(20, 20))
			frame:Destroy()
		end)

		it("binds both ways with Element.model", function()
			local name = ref("Lucy")
			local box = new("TextBox")({ [Element.model("Text")] = name })
			expect(box.Text).to.equal("Lucy")
			name("Goat")
			expect(box.Text).to.equal("Goat")
			box.Text = "Typed"
			task.wait()
			expect(name()).to.equal("Typed")
			box:Destroy()
		end)

		it("hands the instance to a ref with Element.instance", function()
			local target = ref(nil :: any)
			local frame = new("Frame")({ [Element.instance] = target })
			expect(target()).to.equal(frame)
			frame:Destroy()
		end)
	end)

	describe("children", function()
		it("parents children in order with ascending LayoutOrder", function()
			local list = new("Frame")({
				new("TextLabel")({ Name = "A" }),
				{ new("TextLabel")({ Name = "B" }), new("TextLabel")({ Name = "C" }) },
				false,
				nil,
				new("UIListLayout")({}),
			})
			local a, b, c = list:FindFirstChild("A"), list:FindFirstChild("B"), list:FindFirstChild("C")
			expect(a.Parent).to.equal(list)
			expect(a.LayoutOrder < b.LayoutOrder).to.equal(true)
			expect(b.LayoutOrder < c.LayoutOrder).to.equal(true)
			expect(list:FindFirstChildOfClass("UIListLayout")).to.be.ok()
			list:Destroy()
		end)

		it("accepts named children in Children", function()
			local frame = new("Frame")({ Children = { Title = new("TextLabel")({}) } })
			expect(frame:FindFirstChild("Title")).to.be.ok()
			frame:Destroy()
		end)

		it("accepts component handles (anything with .Instance)", function()
			local inner = new("Frame")({ Name = "Inner" })
			local frame = new("Frame")({ { Instance = inner } })
			expect(inner.Parent).to.equal(frame)
			frame:Destroy()
		end)

		it("keeps an explicit LayoutOrder", function()
			local frame = new("Frame")({ new("Frame")({ Name = "X", LayoutOrder = 7 }) })
			expect(frame.X.LayoutOrder).to.equal(7)
			frame:Destroy()
		end)
	end)

	describe("show", function()
		it("mounts a branch while the condition is true and destroys it after", function()
			local open = ref(false)
			local frame = new("Frame")({
				Element.show(open, function()
					return new("TextLabel")({ Name = "Panel" })
				end, function()
					return new("TextLabel")({ Name = "Closed" })
				end),
			})
			expect(frame:FindFirstChild("Panel")).to.equal(nil)
			expect(frame:FindFirstChild("Closed")).to.be.ok()
			open(true)
			local panel = frame:FindFirstChild("Panel")
			expect(panel).to.be.ok()
			expect(frame:FindFirstChild("Closed")).to.equal(nil)
			open(false)
			expect(panel.Parent).to.equal(nil)
			frame:Destroy()
		end)

		it("does not rebuild the branch when the condition stays truthy", function()
			local count = ref(1)
			local builds = 0
			local frame = new("Frame")({
				Element.show(function()
					return count() > 0
				end, function()
					builds += 1
					return new("Frame")({})
				end),
			})
			count(2)
			count(3)
			expect(builds).to.equal(1)
			frame:Destroy()
		end)
	end)

	describe("each", function()
		it("renders one child per item and keeps instances for items that stay", function()
			local a, b, c = { name = "a" }, { name = "b" }, { name = "c" }
			local items = ref({ a, b })
			local frame = new("Frame")({
				Element.each(items, function(item)
					return new("TextLabel")({ Name = item.name })
				end),
			})
			local labelA = frame:FindFirstChild("a")
			expect(labelA).to.be.ok()
			expect(frame:FindFirstChild("b")).to.be.ok()
			items({ c, a })
			expect(frame:FindFirstChild("a")).to.equal(labelA)
			expect(frame:FindFirstChild("b")).to.equal(nil)
			expect(frame.c.LayoutOrder < frame.a.LayoutOrder).to.equal(true)
			frame:Destroy()
		end)

		it("passes a reactive index and supports a key function", function()
			local items = ref({ { id = 1 }, { id = 2 } })
			local frame = new("Frame")({
				Element.each(items, function(item, index)
					return new("TextLabel")({
						Name = tostring(item.id),
						Text = function()
							return tostring(index())
						end,
					})
				end, {
					key = function(item)
						return item.id
					end,
				}),
			})
			local first = frame:FindFirstChild("1")
			expect(first.Text).to.equal("1")
			items({ { id = 2 }, { id = 1 } }) -- new tables, same keys
			expect(frame:FindFirstChild("1")).to.equal(first)
			expect(first.Text).to.equal("2")
			frame:Destroy()
		end)

		it("works with reactive lists and Reactive.insert", function()
			local list = Reactive.reactive({ "x" })
			local frame = new("Frame")({
				Element.each(list, function(name)
					return new("Frame")({ Name = name })
				end),
			})
			Reactive.insert(list, "y")
			expect(frame:FindFirstChild("y")).to.be.ok()
			Reactive.remove(list, 1)
			expect(frame:FindFirstChild("x")).to.equal(nil)
			frame:Destroy()
		end)
	end)

	describe("hydrate", function()
		it("binds an existing instance without owning it", function()
			local text = ref("one")
			local label = Instance.new("TextLabel")
			local _, scope = scoped(function()
				return hydrate(label)({ Text = text })
			end)
			text("two")
			expect(label.Text).to.equal("two")
			scope:stop()
			text("three")
			expect(label.Text).to.equal("two")
			expect(label.Parent).to.equal(nil)
			label.Parent = workspace -- still usable, not destroyed
			expect(label.Parent).to.equal(workspace)
			label:Destroy()
		end)
	end)
end
