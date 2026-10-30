return function()
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, scenes
	local log

	local function define(name, def)
		def = def or {}
		scenes:register(name, {
			layer = def.layer,
			keepAlive = def.keepAlive,
			build = function(scene)
				table.insert(log, "build:" .. name)
				local frame = Instance.new("Frame")
				frame.Name = "Root"
				frame.Parent = scene.gui
			end,
			enter = function(scene, params)
				table.insert(log, "enter:" .. name)
				scene.lastParams = params
			end,
			exit = function()
				table.insert(log, "exit:" .. name)
			end,
		})
	end

	beforeEach(function()
		app, cleanup = Harness.app()
		scenes = app.scenes
		log = {}
		define("Title")
		define("Game")
		define("Pause", { layer = "modal" })
		define("Hud", { layer = "overlay" })
	end)
	afterEach(function()
		cleanup()
	end)

	describe("screens", function()
		it("builds lazily on first visit", function()
			expect(#log).to.equal(0)
			scenes:goTo("Title")
			expect(log[1]).to.equal("build:Title")
			expect(log[2]).to.equal("enter:Title")
			expect(scenes:get("Title").gui:FindFirstChild("Root")).to.be.ok()
		end)

		it("shows exactly one screen at a time", function()
			scenes:goTo("Title")
			scenes:goTo("Game", { map = "Docks" })
			expect(scenes:current()).to.equal("Game")
			expect(scenes:get("Title").gui.Enabled).to.equal(false)
			expect(scenes:get("Game").gui.Enabled).to.equal(true)
			expect(scenes:get("Game").lastParams.map).to.equal("Docks")
			expect(table.find(log, "exit:Title") < table.find(log, "enter:Game")).to.equal(true)
		end)

		it("reuses a kept-alive scene without rebuilding", function()
			scenes:goTo("Title")
			scenes:goTo("Game")
			scenes:goTo("Title")
			local builds = 0
			for _, entry in log do
				if entry == "build:Title" then
					builds += 1
				end
			end
			expect(builds).to.equal(1)
		end)

		it("destroys scenes registered with keepAlive = false", function()
			define("Credits", { keepAlive = false })
			scenes:goTo("Credits")
			local gui = scenes:get("Credits").gui
			scenes:goTo("Title")
			expect(gui.Parent).to.equal(nil)
		end)

		it("navigates when app state changes", function()
			app.state:set("scenes.current", "Game")
			expect(scenes:current()).to.equal("Game")
			expect(scenes:get("Game").gui.Enabled).to.equal(true)
		end)

		it("mirrors navigation into app state", function()
			scenes:goTo("Game")
			expect(app.state:get("scenes.current")).to.equal("Game")
		end)

		it("errors on unknown scenes and wrong layers", function()
			expect(function()
				scenes:goTo("Nope")
			end).to.throw()
			expect(function()
				scenes:goTo("Pause")
			end).to.throw()
			expect(function()
				scenes:push("Game")
			end).to.throw()
		end)

		it("fires Changed with current and previous", function()
			local seen
			scenes.Changed:Connect(function(current, previous)
				seen = { current, previous }
			end)
			scenes:goTo("Title")
			scenes:goTo("Game")
			expect(seen[1]).to.equal("Game")
			expect(seen[2]).to.equal("Title")
		end)
	end)

	describe("stack and overlays", function()
		it("pushes modals above the current screen and keeps it visible", function()
			scenes:goTo("Game")
			scenes:push("Pause")
			local game = scenes:get("Game").gui
			local pause = scenes:get("Pause").gui
			expect(game.Enabled).to.equal(true)
			expect(pause.Enabled).to.equal(true)
			expect(pause.DisplayOrder > game.DisplayOrder).to.equal(true)
			expect(pause:FindFirstChild("Blocker")).to.be.ok()
		end)

		it("pops the top of the stack", function()
			scenes:goTo("Game")
			scenes:push("Pause")
			expect(scenes:pop()).to.equal("Pause")
			expect(scenes:get("Pause").gui.Enabled).to.equal(false)
			expect(scenes:pop()).to.equal(nil)
		end)

		it("shows and hides overlays independently of the screen", function()
			scenes:goTo("Game")
			scenes:show("Hud")
			expect(scenes:isVisible("Hud")).to.equal(true)
			scenes:goTo("Title")
			expect(scenes:isVisible("Hud")).to.equal(true)
			scenes:hide("Hud")
			expect(scenes:isVisible("Hud")).to.equal(false)
		end)

		it("pushes a focus scope for screens and modals, not overlays", function()
			scenes:goTo("Game")
			expect(app.input:topScope().root).to.equal(scenes:get("Game").gui)
			scenes:push("Pause")
			expect(app.input:topScope().root).to.equal(scenes:get("Pause").gui)
			scenes:show("Hud")
			expect(app.input:topScope().root).to.equal(scenes:get("Pause").gui)
			scenes:pop()
			expect(app.input:topScope().root).to.equal(scenes:get("Game").gui)
		end)

		it("goes back by popping the stack, then asking the screen", function()
			local backed = 0
			scenes:register("Menu", {
				onBack = function()
					backed += 1
				end,
			})
			scenes:goTo("Menu")
			scenes:push("Pause")
			expect(app.input:back()).to.equal(true)
			expect(scenes:isVisible("Pause")).to.equal(false)
			expect(app.input:back()).to.equal(true)
			expect(backed).to.equal(1)
		end)

		it("keeps scene guis themed", function()
			scenes:goTo("Title")
			local link = scenes:get("Title").gui:FindFirstChildOfClass("StyleLink")
			expect(link.StyleSheet).to.equal(app.theme.design)
		end)
	end)
end
