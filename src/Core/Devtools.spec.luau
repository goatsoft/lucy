return function()
	local CollectionService = game:GetService("CollectionService")

	local Devtools = require(script.Parent.Devtools)
	local Button = require(script.Parent.Parent.Components.Button)
	local Dialog = require(script.Parent.Parent.Components.Dialog)
	local Panel = require(script.Parent.Parent.Components.Panel)
	local Switch = require(script.Parent.Parent.Components.Switch)
	local ToggleGroup = require(script.Parent.Parent.Components.ToggleGroup)
	local NumberField = require(script.Parent.Parent.Components.NumberField)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local PREFIX = "DevtoolsTest_"

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ namePrefix = PREFIX, state = { player = { coins = 3 } } })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	-- The first node in `nodes` (depth first) whose id is `id`.
	local function find(nodes: { any }, id: string): any
		for _, node in nodes do
			if node.id == id then
				return node
			end
			local found = find(node.children or {}, id)
			if found then
				return found
			end
		end
		return nil
	end

	describe("the bridge", function()
		it("is made in Studio, tagged, and goes with the app", function()
			local bridge = app.parent:FindFirstChild(PREFIX .. "Devtools")
			expect(bridge ~= nil).to.equal(true)
			expect(bridge:IsA("BindableFunction")).to.equal(true)
			expect(table.find(CollectionService:GetTagged("LucyDevtools"), bridge) ~= nil).to.equal(true)
			-- Never copied into Play or saved with the place, where it would answer nothing.
			expect(bridge.Archivable).to.equal(false)
			cleanup()
			expect(bridge.Parent).to.equal(nil)
		end)

		it("skips a bridge that does not answer", function()
			local dead = Instance.new("BindableFunction")
			dead.Name = "Dead_Devtools"
			dead:SetAttribute("LucyApp", "Dead_")
			CollectionService:AddTag(dead, "LucyDevtools")
			dead.Parent = app.parent
			local previous = Devtools.timeout
			Devtools.timeout = 0.5
			local started = os.clock()
			local list = Devtools.apps()
			Devtools.timeout = previous
			dead:Destroy()
			expect(os.clock() - started < 1.5).to.equal(true)
			for _, entry in list do
				expect(entry.name).never.to.equal("Dead_")
			end
		end)

		it("is left out with devtools = false", function()
			local other, stop = Harness.app({ namePrefix = "NoDevtools_", devtools = false })
			expect(other.parent:FindFirstChild("NoDevtools_Devtools")).to.equal(nil)
			stop()
		end)

		it("lists running apps", function()
			local list = Devtools.apps()
			local mine
			for _, entry in list do
				if entry.name == PREFIX then
					mine = entry
				end
			end
			expect(mine ~= nil).to.equal(true)
			expect(mine.theme).to.equal(app.theme:get())
			expect(type(mine.mode)).to.equal("string")
		end)

		it("reaches an app by its name prefix", function()
			Button.new({ app = app, Parent = gui, id = "buy", text = "Buy" })
			local tree = Devtools.tree({ app = PREFIX })
			expect(find(tree, "buy") ~= nil).to.equal(true)
			expect(Devtools.state("player.coins", { app = PREFIX })).to.equal(3)
		end)

		it("picks the game's main app when several run", function()
			local other, stop = Harness.app({ namePrefix = "DevtoolsOther_" })
			-- Harness apps are never current; mark this one as App.new would.
			app.parent:FindFirstChild(PREFIX .. "Devtools"):SetAttribute("LucyCurrent", true)
			local ok, result = pcall(Devtools.state, "player.coins")
			stop()
			local _ = other
			expect(ok).to.equal(true)
			expect(result).to.equal(3)
		end)

		it("names the apps when it can't tell which one is meant", function()
			local other, stop = Harness.app({ namePrefix = "DevtoolsOther_" })
			local ok, err = pcall(Devtools.tree)
			stop()
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), PREFIX, 1, true) ~= nil).to.equal(true)
			expect(string.find(tostring(err), "DevtoolsOther_", 1, true) ~= nil).to.equal(true)
			local _ = other
		end)
	end)

	describe("tree", function()
		it("nests components with their kind, text, state and flags", function()
			local buy = Button.new({ app = app, id = "buy", text = "Buy", disabled = true })
			Panel.new({ app = app, Parent = gui, id = "shop", title = "Shop", children = { buy } })
			local tree = Devtools.tree({ app = app })
			local shop = find(tree, "shop")
			expect(shop.kind).to.equal("panel")
			local node = find(shop.children, "buy")
			expect(node.kind).to.equal("button")
			expect(node.text).to.equal("Buy")
			expect(node.state.disabled).to.equal(true)
			expect(table.find(node.flags, "disabled") ~= nil).to.equal(true)
			expect(type(node.size[1])).to.equal("number")
			expect(type(node.shown)).to.equal("boolean")
		end)

		it("starts from a component with root", function()
			local buy = Button.new({ app = app, id = "buy", text = "Buy" })
			Panel.new({ app = app, Parent = gui, id = "shop", children = { buy } })
			local tree = Devtools.tree({ app = app, root = "buy" })
			expect(#tree).to.equal(1)
			expect(tree[1].id).to.equal("buy")
		end)
	end)

	describe("state", function()
		it("returns a plain copy, the whole store or one path", function()
			app.state:set("player.spawn", workspace)
			expect(Devtools.state("player.coins", { app = app })).to.equal(3)
			local whole = Devtools.state(nil, { app = app })
			expect(whole.player.coins).to.equal(3)
			expect(whole.player.spawn).to.equal("Workspace")
		end)
	end)

	describe("acting", function()
		it("presses a button the way the player would", function()
			local clicks = 0
			Button.new({
				app = app,
				Parent = gui,
				id = "buy",
				text = "Buy",
				onClick = function()
					clicks += 1
				end,
			})
			local result = Devtools.press("buy", nil, { app = app })
			expect(result.ok).to.equal(true)
			expect(clicks).to.equal(1)
		end)

		it("leaves a disabled button alone", function()
			local clicks = 0
			Button.new({
				app = app,
				Parent = gui,
				id = "buy",
				disabled = true,
				onClick = function()
					clicks += 1
				end,
			})
			local result = Devtools.press("buy", nil, { app = app })
			expect(result.ok).to.equal(false)
			expect(clicks).to.equal(0)
		end)

		it("toggles a switch and picks a value in a group", function()
			local switch = Switch.new({ app = app, Parent = gui, id = "music" })
			local group =
				ToggleGroup.new({ app = app, Parent = gui, id = "theme", items = { "dark", "light" } })
			Devtools.press("music", nil, { app = app })
			expect(switch:get("checked")).to.equal(true)
			Devtools.press("theme", "light", { app = app })
			expect(group:get("value")).to.equal("light")
		end)

		it("errors on an unknown id", function()
			expect(function()
				Devtools.press("nope", nil, { app = app })
			end).to.throw()
		end)

		it("writes app state", function()
			Devtools.set("player.coins", 10, { app = app })
			expect(app.state:get("player.coins")).to.equal(10)
		end)

		it("moves focus to a component and reports it", function()
			Button.new({ app = app, Parent = gui, id = "buy", text = "Buy" })
			local result = Devtools.focus("buy", { app = app })
			expect(result.focused.id).to.equal("buy")
			expect(app.input:focused()).to.equal(app:handle("buy").Instance)
			-- Navigating, as a keyboard or gamepad player would be, so the ring shows.
			expect(result.navigating).to.equal(true)
		end)
	end)

	describe("focus inside", function()
		it("lands on the first selectable part of a component", function()
			local field = NumberField.new({ app = app, Parent = gui, id = "count", value = 1 })
			local result = Devtools.focus("count", { app = app })
			-- Its text box is a component of its own; "count" is the one around it.
			expect(table.find(result.focused.within, "count") ~= nil).to.equal(true)
			local focused = app.input:focused()
			expect(focused ~= nil and focused:IsDescendantOf(field.Instance)).to.equal(true)
		end)
	end)

	describe("overlays and actions", function()
		it("lists open overlays, top last", function()
			local dialog = Dialog.new({ app = app, id = "quit", title = "Quit?" })
			dialog:open()
			local result = Devtools.overlays({ app = app })
			expect(result.modalOpen).to.equal(true)
			expect(result.open[#result.open].modal).to.equal(true)
		end)

		it("lists action sets with their keys", function()
			app.actions:define("gameplay", { interact = { Enum.KeyCode.E } })
			local release = app.actions:disable("gameplay")
			local result = Devtools.actions({ app = app })
			local set = result.sets.gameplay
			expect(set.enabled).to.equal(false)
			expect(set.actions.interact[1]).to.equal("E")
			release()
		end)
	end)
end
