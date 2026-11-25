return function()
	local Floating = require(script.Parent.Floating)
	local Reactive = require(script.Parent.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local view = Vector2.new(1000, 600)
	local function rect(x, y, w, h)
		return { position = Vector2.new(x, y), size = Vector2.new(w, h) }
	end

	describe("Floating.compute", function()
		it("puts it above the reference, centred, the offset away", function()
			local at = Floating.compute({
				view = view,
				content = Vector2.new(100, 40),
				reference = rect(450, 300, 100, 30),
				side = "top",
				align = "center",
				offset = 8,
			})
			expect(at.side).to.equal("top")
			expect(at.position).to.equal(Vector2.new(450, 252))
		end)

		it("goes below, left and right", function()
			local base = {
				view = view,
				content = Vector2.new(100, 40),
				reference = rect(450, 300, 100, 30),
				offset = 8,
			}
			local function on(side)
				local input = table.clone(base)
				input.side = side
				return Floating.compute(input)
			end
			expect(on("bottom").position).to.equal(Vector2.new(450, 338))
			expect(on("left").position).to.equal(Vector2.new(342, 295))
			expect(on("right").position).to.equal(Vector2.new(558, 295))
		end)

		it("aligns to the start or end of the reference", function()
			local base = {
				view = view,
				content = Vector2.new(60, 20),
				reference = rect(400, 300, 100, 30),
				side = "top",
			}
			local input = table.clone(base)
			input.align = "start"
			expect(Floating.compute(input).position.X).to.equal(400)
			input.align = "end"
			expect(Floating.compute(input).position.X).to.equal(440)
		end)

		it("flips to the other side when there is no room and the other side has more", function()
			local at = Floating.compute({
				view = view,
				content = Vector2.new(100, 40),
				reference = rect(450, 10, 100, 30),
				side = "top",
				offset = 8,
			})
			expect(at.side).to.equal("bottom")
			expect(at.position.Y).to.equal(48)
		end)

		it("does not flip with flip = false", function()
			local at = Floating.compute({
				view = view,
				content = Vector2.new(100, 40),
				reference = rect(450, 10, 100, 30),
				side = "top",
				flip = false,
			})
			expect(at.side).to.equal("top")
		end)

		it("shifts along its side to stay on screen, and the arrow still points at the reference", function()
			local at = Floating.compute({
				view = view,
				content = Vector2.new(200, 40),
				reference = rect(0, 300, 40, 30),
				side = "top",
				align = "center",
				padding = 8,
				arrow = 10,
			})
			expect(at.position.X).to.equal(8)
			-- the reference's centre is at x 20, the content starts at 8
			expect(at.arrow).to.equal(12)
		end)

		it("keeps the arrow off the rounded corners", function()
			local at = Floating.compute({
				view = view,
				content = Vector2.new(200, 40),
				reference = rect(0, 300, 4, 30),
				side = "top",
				padding = 0,
				arrow = 10,
				arrowPadding = 6,
			})
			expect(at.arrow).to.equal(11)
		end)

		it("centres arrowCenter when aligned to center, and offsets it when shifted", function()
			local centered = Floating.compute({
				view = view,
				content = Vector2.new(163, 22),
				reference = rect(258, 400, 83, 36),
				side = "top",
				align = "center",
				arrow = 10,
			})
			expect(centered.arrowCenter).to.equal(0)

			local shifted = Floating.compute({
				view = view,
				content = Vector2.new(200, 40),
				reference = rect(0, 300, 40, 30),
				side = "top",
				align = "center",
				padding = 8,
				arrow = 10,
			})
			-- reference center = 20, floating center = 8 + 100 = 108 -> center offset = -88
			expect(shifted.arrowCenter).to.equal(-88)
		end)

		it("supports alignOffset, sideOffset, collisionPadding and avoidCollisions = false", function()
			local offsetTop = Floating.compute({
				view = view,
				content = Vector2.new(100, 40),
				reference = rect(450, 300, 100, 30),
				side = "top",
				align = "start",
				sideOffset = 12,
				alignOffset = 15,
			})
			expect(offsetTop.position).to.equal(Vector2.new(465, 248))

			local noAvoid = Floating.compute({
				view = view,
				content = Vector2.new(100, 40),
				reference = rect(450, 10, 100, 30),
				side = "top",
				avoidCollisions = false,
			})
			expect(noAvoid.side).to.equal("top")

			local padded = Floating.compute({
				view = view,
				content = Vector2.new(200, 40),
				reference = rect(0, 300, 40, 30),
				side = "top",
				collisionPadding = 16,
			})
			expect(padded.position.X).to.equal(16)
		end)

		it("keeps out of the top inset", function()
			local at = Floating.compute({
				view = view,
				content = Vector2.new(40, 200),
				reference = rect(0, 100, 30, 30),
				side = "right",
				align = "center",
				padding = 8,
				top = 36,
			})
			expect(at.position.Y).to.equal(44)
		end)

		it("rejects an unknown side or align", function()
			expect(function()
				Floating.compute({
					view = view,
					content = Vector2.one,
					reference = rect(0, 0, 1, 1),
					side = "over",
				})
			end).to.throw()
			expect(function()
				Floating.compute({
					view = view,
					content = Vector2.one,
					reference = rect(0, 0, 1, 1),
					align = "middle",
				})
			end).to.throw()
		end)
	end)

	describe("Floating.worldOffset", function()
		it("lifts it above the part by half its height and the gap", function()
			local offset, sizeOffset = Floating.worldOffset("top", Vector3.new(4, 6, 4), 0.5)
			expect(offset).to.equal(Vector3.new(0, 3.5, 0))
			expect(sizeOffset).to.equal(Vector2.new(0, 0.5))
			local below, under = Floating.worldOffset("bottom", Vector3.new(4, 6, 4), 0.5)
			expect(below).to.equal(Vector3.new(0, -3.5, 0))
			expect(under).to.equal(Vector2.new(0, -0.5))
			local right, beside = Floating.worldOffset("right", Vector3.new(4, 6, 2), 0)
			expect(right).to.equal(Vector3.new(2, 0, 0))
			expect(beside).to.equal(Vector2.new(0.5, 0))
		end)
	end)

	describe("Floating.use", function()
		local app, cleanup
		beforeEach(function()
			app, cleanup = Harness.app()
		end)
		afterEach(function()
			cleanup()
		end)

		it("needs an owner", function()
			expect(function()
				Floating.use(app, { reference = Instance.new("Frame"), content = Instance.new("Frame") })
			end).to.throw()
		end)

		it("floats by a gui object in the overlay layer, shown while open", function()
			local gui = app:createGui("FloatHost")
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(100, 30)
			button.Position = UDim2.fromOffset(400, 300)
			button.Parent = gui
			local content = Instance.new("Frame")
			content.Size = UDim2.fromOffset(80, 20)
			local open = Reactive.ref(false)
			local floating
			local scope = Reactive.effectScope(true)
			scope:run(function()
				floating =
					Floating.use(app, { reference = button, content = content, open = open, side = "top" })
			end)
			expect(floating.world).to.equal(false)
			expect(content:IsDescendantOf(app:portal("modal"))).to.equal(true)
			expect(floating.visible()).to.equal(false)
			open(true)
			expect(floating.visible()).to.equal(true)
			expect(floating.side()).to.equal("top")
			-- Not modal: it never takes focus or a back press
			expect(app.input:back()).to.equal(false)
			scope:stop()
		end)

		it("floats by a part in a billboard that is on only while open", function()
			local part = Instance.new("Part")
			part.Size = Vector3.new(4, 6, 4)
			part.Parent = workspace
			local content = Instance.new("Frame")
			content.Size = UDim2.fromOffset(80, 20)
			local open = Reactive.ref(false)
			local floating
			local scope = Reactive.effectScope(true)
			scope:run(function()
				floating =
					Floating.use(app, { reference = part, content = content, open = open, side = "top" })
			end)
			expect(floating.world).to.equal(true)
			local gui = floating.gui :: BillboardGui
			expect(gui:IsA("BillboardGui")).to.equal(true)
			expect(gui.Adornee).to.equal(part)
			expect(content.Parent ~= nil and content:IsDescendantOf(gui)).to.equal(true)
			expect(gui.Enabled).to.equal(false)
			open(true)
			expect(gui.Enabled).to.equal(true)
			expect(gui.SizeOffset).to.equal(Vector2.new(0, 0.5))
			scope:stop()
			expect(gui.Parent).to.equal(nil)
			part:Destroy()
		end)

		it("hangs from a model's primary part", function()
			local model = Instance.new("Model")
			local part = Instance.new("Part")
			part.Parent = model
			model.PrimaryPart = part
			model.Parent = workspace
			local scope = Reactive.effectScope(true)
			local floating
			scope:run(function()
				floating = Floating.use(app, {
					reference = model,
					content = Instance.new("Frame"),
					open = Reactive.ref(true),
				})
			end)
			expect((floating.gui :: BillboardGui).Adornee).to.equal(part)
			scope:stop()
			model:Destroy()
		end)
	end)
end
