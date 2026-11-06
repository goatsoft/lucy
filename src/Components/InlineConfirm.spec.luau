return function()
	local Button = require(script.Parent.Button)
	local InlineConfirm = require(script.Parent.InlineConfirm)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local function make(props: { [string]: any }?)
		local label = Instance.new("TextLabel")
		label.Text = "The shop sells new looks."
		local options: { [string]: any } = { app = app, Parent = gui, children = { label } }
		for key, value in props or {} do
			options[key] = value
		end
		return InlineConfirm.new(options), label
	end

	it("shows its content until it asks", function()
		local confirm, label = make()
		expect(label:IsDescendantOf(confirm.content)).to.equal(true)
		expect(confirm.content.Visible).to.equal(true)
		expect(confirm.prompt.Visible).to.equal(false)
		expect(confirm.asking()).to.equal(false)
	end)

	it("swaps the content for the question and YES / NO", function()
		local confirm = make()
		confirm:ask()
		expect(confirm.asking()).to.equal(true)
		expect(confirm.content.Visible).to.equal(false)
		expect(confirm.prompt.Visible).to.equal(true)
		expect(confirm.question.Text).to.equal("Are you sure?")
		expect(confirm.yes:get("text")).to.equal("YES")
		expect(confirm.no:get("text")).to.equal("NO")
	end)

	it("takes its own words", function()
		local confirm =
			make({ question = "Skip the tour?", yes = "SKIP", no = "STAY", noVariant = "default" })
		confirm:ask()
		expect(confirm.question.Text).to.equal("Skip the tour?")
		expect(confirm.yes:get("text")).to.equal("SKIP")
		expect(confirm.no:get("text")).to.equal("STAY")
		expect(confirm.no:get("variant")).to.equal("default")
	end)

	it("NO puts the content back", function()
		local said
		local confirm = make({
			onNo = function()
				said = "no"
			end,
		})
		confirm:ask()
		confirm.no:click()
		expect(said).to.equal("no")
		expect(confirm.asking()).to.equal(false)
		expect(confirm.content.Visible).to.equal(true)
	end)

	it("YES answers and puts the content back", function()
		local said
		local confirm = make({
			onYes = function()
				said = "yes"
			end,
		})
		confirm:ask()
		confirm.yes:click()
		expect(said).to.equal("yes")
		expect(confirm.asking()).to.equal(false)
		expect(confirm.content.Visible).to.equal(true)
	end)

	it("back answers NO while it asks, and only then", function()
		local said
		local confirm = make({
			onNo = function()
				said = "no"
			end,
		})
		local before = app.input:back()
		confirm:ask()
		expect(app.input:back()).to.equal(true)
		expect(said).to.equal("no")
		expect(confirm.asking()).to.equal(false)
		expect(app.input:back()).to.equal(before)
	end)

	it("cancel puts the content back without an answer", function()
		local said
		local confirm = make({
			onNo = function()
				said = "no"
			end,
		})
		confirm:ask()
		confirm:cancel()
		expect(confirm.asking()).to.equal(false)
		expect(said).to.equal(nil)
	end)

	it("focuses NO, and gives focus back after NO", function()
		local opener = Button.new({ app = app, Parent = gui, text = "SKIP" })
		Harness.flush()
		app.input:setMode("gamepad")
		app.input:focus(opener.Instance)
		local confirm = make()
		confirm:ask()
		Harness.flush()
		expect(app.input:focused()).to.equal(confirm.no.Instance)
		confirm.no:click()
		Harness.flush()
		expect(app.input:focused()).to.equal(opener.Instance)
	end)
end
