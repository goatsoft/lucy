return function()
	local Select = require(script.Parent.Select)
	local Icon = require(script.Parent.Icon)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local ITEMS = {
		{ value = "eu", label = "Europe" },
		{ value = "na", label = "North America" },
		{ value = "as", label = "Asia", disabled = true },
		"Oceania",
	}

	local function make(props: { [string]: any }?)
		local p = table.clone(props or {})
		p.app = app
		p.items = p.items or ITEMS
		p.Parent = gui
		p.size = p.size or UDim2.fromOffset(220, 36)
		return Select.new(p)
	end

	it("shows the placeholder until something is picked, then its label", function()
		local picker = make({ placeholder = "Region" })
		expect(picker.valueLabel.Text).to.equal("Region")
		expect(picker.valueLabel:HasTag("ui-select-placeholder")).to.equal(true)
		picker:select("na")
		expect(picker.valueLabel.Text).to.equal("North America")
		expect(picker.valueLabel:HasTag("ui-select-placeholder")).to.equal(false)
	end)

	it("draws the lucy:chevron-down icon on the trigger", function()
		local picker = make()
		local slot: any = Icon.resolve("lucy:chevron-down")
		expect(picker.caret.Instance.Image).to.equal(slot.image)
	end)

	it("opens from the trigger into the modal layer, as a popup on mouse", function()
		local picker = make()
		expect(picker:get("open")).to.equal(false)
		picker:click()
		expect(picker:get("open")).to.equal(true)
		expect(picker.content:IsDescendantOf(app:portal("modal"))).to.equal(true)
		expect(picker.presentation()).to.equal("popup")
	end)

	it("is a drawer on touch", function()
		app.input:setMode("touch")
		local picker = make()
		picker:open()
		expect(picker.presentation()).to.equal("drawer")
	end)

	it("sits under the trigger, at least as wide", function()
		local picker = make()
		picker.Instance.Position = UDim2.fromOffset(40, 40)
		task.wait(0.1)
		picker:open()
		task.wait(0.2)
		local trigger, content = picker.Instance, picker.content
		expect(content.AbsoluteSize.X >= trigger.AbsoluteSize.X - 1).to.equal(true)
		expect(content.AbsolutePosition.Y >= trigger.AbsolutePosition.Y + trigger.AbsoluteSize.Y).to.equal(
			true
		)
		expect(math.abs(content.AbsolutePosition.X - trigger.AbsolutePosition.X) <= 2).to.equal(true)
	end)

	it("picks an option, reports it and closes", function()
		local changes = {}
		local picker = make({
			onValueChange = function(value)
				table.insert(changes, value)
			end,
		})
		picker:open()
		picker:select("na")
		expect(picker:get("value")).to.equal("na")
		expect(picker:get("open")).to.equal(false)
		expect(changes[1]).to.equal("na")
		expect(picker.items[2].root:HasTag("ui-selected")).to.equal(true)
		expect(picker.items[1].root:HasTag("ui-selected")).to.equal(false)
	end)

	it("draws no ticks by default", function()
		local picker = make({ value = "eu" })
		expect(picker.items[1].check).to.equal(nil)
		picker:open()
		Harness.flush()
		expect(Harness.styled(picker.items[1].root, "BackgroundTransparency")).to.equal(0)
	end)

	it("draws the lucy:check tick in front of the label for type check", function()
		local picker = make({ type = "check", value = "na" })
		picker:open()
		task.wait(0.2)
		local row = picker.items[2]
		local slot: any = Icon.resolve("lucy:check")
		expect(row.check.Instance.Image).to.equal(slot.image)
		expect(row.check.Instance.Visible).to.equal(true)
		expect(picker.items[1].check.Instance.Visible).to.equal(false)
		expect(row.check.Instance.AbsolutePosition.X < row.label.AbsolutePosition.X).to.equal(true)
	end)

	it("rejects an unknown type, and multiple without ticks", function()
		expect(function()
			make({ type = "fancy" })
		end).to.throw()
		expect(function()
			make({ type = "default", multiple = true })
		end).to.throw()
	end)

	describe("multiple", function()
		it("ticks options on and off, keeps the list open, and keeps item order", function()
			local changes = {}
			local picker = make({
				multiple = true,
				onValueChange = function(value)
					table.insert(changes, table.concat(value, ","))
				end,
			})
			expect(#picker:get("value")).to.equal(0)
			picker:open()
			picker:select("Oceania")
			picker:select("eu")
			expect(picker:get("open")).to.equal(true)
			expect(table.concat(picker:get("value"), ",")).to.equal("eu,Oceania")
			expect(picker.items[1].check.Instance.Visible).to.equal(true)
			expect(picker.items[4].check.Instance.Visible).to.equal(true)
			picker:select("eu")
			expect(table.concat(picker:get("value"), ",")).to.equal("Oceania")
			expect(picker.items[1].check.Instance.Visible).to.equal(false)
			expect(changes[#changes]).to.equal("Oceania")
		end)

		it("shows the first label and how many more", function()
			local picker = make({ multiple = true, placeholder = "Regions" })
			expect(picker.valueLabel.Text).to.equal("Regions")
			picker:select("na")
			expect(picker.valueLabel.Text).to.equal("North America")
			picker:select("Oceania")
			picker:select("eu")
			expect(picker.valueLabel.Text).to.equal("Europe +2")
		end)

		it("skips disabled options", function()
			local picker = make({ multiple = true })
			picker:select("as")
			expect(#picker:get("value")).to.equal(0)
		end)
	end)

	it("takes plain values as items, shown as their text", function()
		local picker = make()
		picker:select("Oceania")
		expect(picker.valueLabel.Text).to.equal("Oceania")
	end)

	it("ignores disabled options and does not open when disabled", function()
		local picker = make({ value = "eu" })
		picker:select("as")
		expect(picker:get("value")).to.equal("eu")
		expect(picker.items[3].root.Interactable).to.equal(false)
		local off = make({ disabled = true })
		off:click()
		expect(off:get("open")).to.equal(false)
		expect(off.Instance.Interactable).to.equal(false)
	end)

	it("keeps value in step with a ref, both ways", function()
		local value = Reactive.ref("eu")
		local picker = make({ value = value })
		expect(picker.valueLabel.Text).to.equal("Europe")
		value("na")
		expect(picker.valueLabel.Text).to.equal("North America")
		picker:select("Oceania")
		expect(value()).to.equal("Oceania")
	end)

	it("emits picker with the value", function()
		local Lucy = require(script.Parent.Parent)
		local heard = {}
		local scope = Reactive.effectScope(true)
		local picker
		scope:run(function()
			Lucy.useUiSound(app, {
				select = function(_, value)
					table.insert(heard, value)
				end,
			})
			picker = make()
		end)
		picker:select("na")
		expect(heard[1]).to.equal("na")
		scope:stop()
	end)

	it("closes on back", function()
		local picker = make()
		picker:open()
		expect(app.input:back()).to.equal(true)
		expect(picker:get("open")).to.equal(false)
	end)

	it("selects the picked row on gamepad, and gives focus back to the trigger", function()
		app.input:setMode("gamepad")
		local picker = make({ value = "na" })
		app.input:focus(picker.Instance)
		picker:open()
		expect(app.input:focused()).to.equal(picker.items[2].root)
		picker:select("eu")
		expect(app.input:focused()).to.equal(picker.Instance)
	end)

	it("scrolls a long list inside the space it has", function()
		local many = {}
		for i = 1, 60 do
			table.insert(many, "Option " .. i)
		end
		local picker = make({ items = many })
		task.wait(0.1)
		picker:open()
		task.wait(0.3)
		local list = picker.list.Instance
		expect(list.AbsoluteCanvasSize.Y > list.AbsoluteSize.Y).to.equal(true)
		local root = app:portal("modal").AbsoluteSize
		expect(picker.content.AbsolutePosition.Y + picker.content.AbsoluteSize.Y <= root.Y + 1).to.equal(true)
	end)
end
