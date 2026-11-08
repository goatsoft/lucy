return function()
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	local parts: { Instance } = {}

	local function part(): Part
		local p = Instance.new("Part")
		p.Name = "LucyTest_WorldPart"
		p.Anchored = true
		p.Size = Vector3.new(8, 4, 1)
		p.Archivable = false
		p.Parent = workspace
		table.insert(parts, p)
		return p
	end

	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
	end)
	afterEach(function()
		cleanup()
		for _, p in parts do
			p:Destroy()
		end
		table.clear(parts)
	end)

	describe("createSurface", function()
		it("puts a SurfaceGui on the part, in the app's parent, so it can be clicked", function()
			local board = part()
			local gui = app:createSurface("Board", { adornee = board })
			expect(gui:IsA("SurfaceGui")).to.equal(true)
			expect(gui.Name).to.equal("LucyTest_Board")
			expect(gui.Adornee).to.equal(board)
			expect(gui.Parent).to.equal(app.parent)
			expect(gui.Face).to.equal(Enum.NormalId.Front)
			expect(gui.Active).to.equal(true)
			expect(gui.ResetOnSpawn).to.equal(false)
		end)

		it("sizes by pixels per stud, or to a fixed canvas", function()
			local byStud = app:createSurface("ByStud", { adornee = part(), pixelsPerStud = 80 })
			expect(byStud.SizingMode).to.equal(Enum.SurfaceGuiSizingMode.PixelsPerStud)
			expect(byStud.PixelsPerStud).to.equal(80)

			local fixed = app:createSurface("Fixed", { adornee = part(), canvasSize = Vector2.new(800, 400) })
			expect(fixed.SizingMode).to.equal(Enum.SurfaceGuiSizingMode.FixedSize)
			expect(fixed.CanvasSize).to.equal(Vector2.new(800, 400))
		end)

		it("takes the face, light and distance options", function()
			local gui = app:createSurface("Opts", {
				adornee = part(),
				face = Enum.NormalId.Back,
				lightInfluence = 0.5,
				brightness = 2,
				alwaysOnTop = true,
				maxDistance = 60,
			})
			expect(gui.Face).to.equal(Enum.NormalId.Back)
			expect(gui.LightInfluence).to.equal(0.5)
			expect(gui.Brightness).to.equal(2)
			expect(gui.AlwaysOnTop).to.equal(true)
			expect(gui.MaxDistance).to.equal(60)
		end)

		it("is not lit by the world unless asked", function()
			local gui = app:createSurface("Unlit", { adornee = part() })
			expect(gui.LightInfluence).to.equal(0)
		end)

		it("follows the theme and is never scaled for the screen", function()
			local gui = app:createSurface("Themed", { adornee = part() })
			expect(gui:FindFirstChildOfClass("StyleLink")).to.be.ok()
			expect(gui:FindFirstChildWhichIsA("UIScale", true)).to.equal(nil)

			local label = Instance.new("TextLabel")
			label:AddTag("ui-test-world")
			label.Parent = gui
			app.theme:addRules("worldSpec", {
				{ selector = ".ui-test-world", properties = { BackgroundColor3 = "$Primary" } },
			})
			Harness.flush()
			expect(Harness.colorEq(Harness.styled(label, "BackgroundColor3"), app.theme:resolve("Primary"))).to.equal(
				true
			)
		end)

		it("needs a part", function()
			expect(function()
				app:createSurface("NoPart", {})
			end).to.throw()
		end)

		it("goes when its part goes", function()
			local board = part()
			local gui = app:createSurface("Gone", { adornee = board })
			board:Destroy()
			task.wait()
			expect(gui.Parent).to.equal(nil)
		end)

		it("goes with the app", function()
			local gui = app:createSurface("WithApp", { adornee = part() })
			cleanup()
			expect(gui.Parent).to.equal(nil)
			app, cleanup = Harness.app()
		end)

		it("is kept out of Play and the saved place in edit mode, and left be in a running game", function()
			local RunService = game:GetService("RunService")
			local archivable = not (RunService:IsStudio() and not RunService:IsRunning())
			expect(app:createSurface("Archive", { adornee = part() }).Archivable).to.equal(archivable)
		end)

		it("is not a screen gui for keyboard and gamepad navigation", function()
			local gui = app:createSurface("NotNav", { adornee = part() })
			expect(table.find(app:activeGuis() :: { any }, gui)).to.equal(nil)
		end)
	end)

	describe("createBillboard", function()
		it("puts a BillboardGui over the part, in the app's parent", function()
			local head = part()
			local gui = app:createBillboard("Tag", { adornee = head })
			expect(gui:IsA("BillboardGui")).to.equal(true)
			expect(gui.Name).to.equal("LucyTest_Tag")
			expect(gui.Adornee).to.equal(head)
			expect(gui.Parent).to.equal(app.parent)
			expect(gui.Active).to.equal(true)
			expect(gui.ResetOnSpawn).to.equal(false)
			expect(gui.LightInfluence).to.equal(0)
		end)

		it("takes size, offset and distance options", function()
			local gui = app:createBillboard("Opts", {
				adornee = part(),
				size = UDim2.fromOffset(200, 50),
				studsOffset = Vector3.new(0, 3, 0),
				alwaysOnTop = true,
				maxDistance = 40,
			})
			expect(gui.Size).to.equal(UDim2.fromOffset(200, 50))
			expect(gui.StudsOffset).to.equal(Vector3.new(0, 3, 0))
			expect(gui.AlwaysOnTop).to.equal(true)
			expect(gui.MaxDistance).to.equal(40)
		end)

		it("can hang from an attachment", function()
			local attachment = Instance.new("Attachment")
			attachment.Parent = part()
			local gui = app:createBillboard("OnAttachment", { adornee = attachment })
			expect(gui.Adornee).to.equal(attachment)
		end)

		it("follows the theme and is never scaled for the screen", function()
			local gui = app:createBillboard("Themed", { adornee = part() })
			expect(gui:FindFirstChildOfClass("StyleLink")).to.be.ok()
			expect(gui:FindFirstChildWhichIsA("UIScale", true)).to.equal(nil)
		end)

		it("goes when its part goes", function()
			local head = part()
			local gui = app:createBillboard("Gone", { adornee = head })
			head:Destroy()
			task.wait()
			expect(gui.Parent).to.equal(nil)
		end)

		it("needs a part or attachment", function()
			expect(function()
				app:createBillboard("NoPart", {})
			end).to.throw()
		end)
	end)

	it("lets Devtools see components in the world", function()
		local Devtools = require(script.Parent.Devtools)
		local Button = require(script.Parent.Parent.Components.Button)
		local gui = app:createSurface("Devtools", { adornee = part() })
		Button.new({ id = "world-button", text = "Vote", app = app, Parent = gui })
		local found = false
		for _, node in Devtools.tree({ app = app }) do
			if node.id == "world-button" then
				found = true
			end
		end
		expect(found).to.equal(true)
	end)
end
