return function()
	local Gradient = require(script.Parent.Gradient)
	local Tokens = require(script.Parent.Parent.Core.Tokens)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local CollectionService = game:GetService("CollectionService")

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local function sameSequence(a: ColorSequence, b: ColorSequence): boolean
		if #a.Keypoints ~= #b.Keypoints then
			return false
		end
		for i, key in a.Keypoints do
			local other = b.Keypoints[i]
			if math.abs(key.Time - other.Time) > 1e-3 or not Harness.colorEq(key.Value, other.Value) then
				return false
			end
		end
		return true
	end

	describe("Tokens.gradient", function()
		it("spaces plain colours evenly and resolves tokens", function()
			local sequence = Tokens.compute(Tokens.gradient({ "$A", "$B", "$A" }), function(ref)
				return if ref == "$A" then Color3.new(1, 0, 0) else Color3.new(0, 0, 1)
			end)
			expect(#sequence.Keypoints).to.equal(3)
			expect(sequence.Keypoints[2].Time).to.equal(0.5)
			expect(Harness.colorEq(sequence.Keypoints[2].Value, Color3.new(0, 0, 1))).to.equal(true)
		end)

		it("takes positions and derived colours", function()
			local sequence = Tokens.compute(
				Tokens.gradient({ { 0, Color3.new(1, 1, 1) }, { 0.7, Tokens.mix("$A", "$A", 0) }, { 1, "$A" } }),
				function()
					return Color3.new(0, 1, 0)
				end
			)
			expect(math.abs(sequence.Keypoints[2].Time - 0.7) < 1e-3).to.equal(true)
			expect(Harness.colorEq(sequence.Keypoints[2].Value, Color3.new(0, 1, 0))).to.equal(true)
		end)

		it("needs two colours", function()
			expect(function()
				Tokens.compute(Tokens.gradient({ "$A" }), function()
					return Color3.new()
				end)
			end).to.throw()
		end)

		it("is in every built-in theme", function()
			for _, values in Tokens.themes do
				expect(values.GradientSurface).to.be.ok()
				expect(values.GradientPrimary).to.be.ok()
			end
			expect(typeof(app.theme:resolve("GradientSurface"))).to.equal("ColorSequence")
		end)
	end)

	it("is a UIGradient with the theme's colours", function()
		local frame = Instance.new("Frame")
		frame.Parent = gui
		local gradient = Gradient.new({ app = app, Parent = frame })
		expect(gradient.Instance:IsA("UIGradient")).to.equal(true)
		expect(gradient.Instance.Rotation).to.equal(90)
		Harness.flush()
		expect(sameSequence(Harness.styled(gradient.Instance, "Color"), app.theme:resolve("GradientSurface"))).to.equal(
			true
		)
	end)

	it("follows a reactive gradient and rotation", function()
		local frame = Instance.new("Frame")
		frame.Parent = gui
		local name, rotation = Reactive.ref("Surface"), Reactive.ref(90)
		local gradient = Gradient.new({ app = app, Parent = frame, gradient = name, rotation = rotation })
		name("Primary")
		rotation(0)
		Harness.flush()
		expect(gradient.Instance.Rotation).to.equal(0)
		expect(CollectionService:HasTag(gradient.Instance, "ui-gradient-primary")).to.equal(true)
		expect(CollectionService:HasTag(gradient.Instance, "ui-gradient-surface")).to.equal(false)
		expect(sameSequence(Harness.styled(gradient.Instance, "Color"), app.theme:resolve("GradientPrimary"))).to.equal(
			true
		)
	end)

	it("lifts its parent's fill to white while it shows", function()
		local frame = Instance.new("Frame")
		frame.Parent = gui
		local visible = Reactive.ref(true)
		local gradient = Gradient.new({ app = app, Parent = frame, visible = visible })
		Harness.flush()
		expect(CollectionService:HasTag(frame, "ui-gradient-host")).to.equal(true)
		expect(Harness.colorEq(Harness.styled(frame, "BackgroundColor3"), Color3.new(1, 1, 1))).to.equal(true)
		visible(false)
		Harness.flush()
		expect(CollectionService:HasTag(frame, "ui-gradient-host")).to.equal(false)
		visible(true)
		Harness.flush()
		gradient:destroy()
		expect(CollectionService:HasTag(frame, "ui-gradient-host")).to.equal(false)
	end)
end
