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
		local select = make({ placeholder = "Region" })
		expect(select.valueLabel.Text).to.equal("Region")
		expect(select.valueLabel:HasTag("ui-select-placeholder")).to.equal(true)
		select:select("na")
		expect(select.valueLabel.Text).to.equal("North America")
		expect(select.valueLabel:HasTag("ui-select-placeholder")).to.equal(false)
	end)

	it("draws the lucy:chevron-down icon on the trigger", function()
		local select = make()
		local slot: any = Icon.resolve("lucy:chevron-down")
		expect(select.caret.Instance.Image).to.equal(slot.image)
	end)

	it("opens from the trigger into the modal layer, as a popup on mouse", function()
		local select = make()
		expect(select:get("open")).to.equal(false)
		select:click()
		expect(select:get("open")).to.equal(true)
		expect(select.content:IsDescendantOf(app:portal("modal"))).to.equal(true)
		expect(select.presentation()).to.equal("popup")
	end)

	it("is a drawer on touch", function()
		app.input:setMode("touch")
		local select = make()
		select:open()
		expect(select.presentation()).to.equal("drawer")
	end)

	it("sits under the trigger, at least as wide", function()
		local select = make()
		select.Instance.Position = UDim2.fromOffset(40, 40)
		task.wait(0.1)
		select:open()
		task.wait(0.2)
		local trigger, content = select.Instance, select.content
		expect(content.AbsoluteSize.X >= trigger.AbsoluteSize.X - 1).to.equal(true)
		expect(content.AbsolutePosition.Y >= trigger.AbsolutePosition.Y + trigger.AbsoluteSize.Y).to.equal(
			true
		)
		expect(math.abs(content.AbsolutePosition.X - trigger.AbsolutePosition.X) <= 2).to.equal(true)
	end)

	it("picks an option, reports it and closes", function()
		local changes = {}
		local select = make({
			onValueChange = function(value)
				table.insert(changes, value)
			end,
		})
		select:open()
		select:select("na")
		expect(select:get("value")).to.equal("na")
		expect(select:get("open")).to.equal(false)
		expect(changes[1]).to.equal("na")
		expect(select.items[2].root:HasTag("ui-selected")).to.equal(true)
		expect(select.items[1].root:HasTag("ui-selected")).to.equal(false)
	end)

	it("draws no ticks by default", function()
		local select = make({ value = "eu" })
		expect(select.items[1].check).to.equal(nil)
		select:open()
		Harness.flush()
		expect(Harness.styled(select.items[1].root, "BackgroundTransparency")).to.equal(0)
	end)

	it("draws the lucy:check tick in front of the label for type check", function()
		local select = make({ type = "check", value = "na" })
		select:open()
		task.wait(0.2)
		local row = select.items[2]
		local slot: any = Icon.resolve("lucy:check")
		expect(row.check.Instance.Image).to.equal(slot.image)
		expect(row.check.Instance.Visible).to.equal(true)
		expect(select.items[1].check.Instance.Visible).to.equal(false)
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
			local select = make({
				multiple = true,
				onValueChange = function(value)
					table.insert(changes, table.concat(value, ","))
				end,
			})
			expect(#select:get("value")).to.equal(0)
			select:open()
			select:select("Oceania")
			select:select("eu")
			expect(select:get("open")).to.equal(true)
			expect(table.concat(select:get("value"), ",")).to.equal("eu,Oceania")
			expect(select.items[1].check.Instance.Visible).to.equal(true)
			expect(select.items[4].check.Instance.Visible).to.equal(true)
			select:select("eu")
			expect(table.concat(select:get("value"), ",")).to.equal("Oceania")
			expect(select.items[1].check.Instance.Visible).to.equal(false)
			expect(changes[#changes]).to.equal("Oceania")
		end)

		it("shows the first label and how many more", function()
			local select = make({ multiple = true, placeholder = "Regions" })
			expect(select.valueLabel.Text).to.equal("Regions")
			select:select("na")
			expect(select.valueLabel.Text).to.equal("North America")
			select:select("Oceania")
			select:select("eu")
			expect(select.valueLabel.Text).to.equal("Europe +2")
		end)

		it("skips disabled options", function()
			local select = make({ multiple = true })
			select:select("as")
			expect(#select:get("value")).to.equal(0)
		end)
	end)

	it("takes plain values as items, shown as their text", function()
		local select = make()
		select:select("Oceania")
		expect(select.valueLabel.Text).to.equal("Oceania")
	end)

	it("ignores disabled options and does not open when disabled", function()
		local select = make({ value = "eu" })
		select:select("as")
		expect(select:get("value")).to.equal("eu")
		expect(select.items[3].root.Interactable).to.equal(false)
		local off = make({ disabled = true })
		off:click()
		expect(off:get("open")).to.equal(false)
		expect(off.Instance.Interactable).to.equal(false)
	end)

	it("keeps value in step with a ref, both ways", function()
		local value = Reactive.ref("eu")
		local select = make({ value = value })
		expect(select.valueLabel.Text).to.equal("Europe")
		value("na")
		expect(select.valueLabel.Text).to.equal("North America")
		select:select("Oceania")
		expect(value()).to.equal("Oceania")
	end)

	it("emits select with the value", function()
		local Lucy = require(script.Parent.Parent)
		local heard = {}
		local scope = Reactive.effectScope(true)
		local select
		scope:run(function()
			Lucy.useUiSound(app, {
				select = function(_, value)
					table.insert(heard, value)
				end,
			})
			select = make()
		end)
		select:select("na")
		expect(heard[1]).to.equal("na")
		scope:stop()
	end)

	it("closes on back", function()
		local select = make()
		select:open()
		expect(app.input:back()).to.equal(true)
		expect(select:get("open")).to.equal(false)
	end)

	it("selects the picked row on gamepad, and gives focus back to the trigger", function()
		app.input:setMode("gamepad")
		local select = make({ value = "na" })
		app.input:focus(select.Instance)
		select:open()
		expect(app.input:focused()).to.equal(select.items[2].root)
		select:select("eu")
		expect(app.input:focused()).to.equal(select.Instance)
	end)

	it("scrolls a long list inside the space it has", function()
		local many = {}
		for i = 1, 60 do
			table.insert(many, "Option " .. i)
		end
		local select = make({ items = many })
		task.wait(0.1)
		select:open()
		task.wait(0.3)
		local list = select.list.Instance
		expect(list.AbsoluteCanvasSize.Y > list.AbsoluteSize.Y).to.equal(true)
		local root = app:portal("modal").AbsoluteSize
		expect(select.content.AbsolutePosition.Y + select.content.AbsoluteSize.Y <= root.Y + 1).to.equal(true)
	end)
end
