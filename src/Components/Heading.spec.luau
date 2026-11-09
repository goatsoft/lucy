return function()
	local Heading = require(script.Parent.Heading)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
	end)
	afterEach(function()
		cleanup()
	end)

	local function make(description: string)
		local frame, title, text
		local scope = Reactive.effectScope()
		scope:run(function()
			frame, title, text = Heading.new(app, {
				title = function()
					return "THE LAB"
				end,
				description = function()
					return description
				end,
				titleTag = "t",
				descriptionTag = "d",
			})
		end)
		return frame, title, text, scope
	end

	it("puts the description under the title, both wrapping", function()
		app.state:set("input.height", "tall")
		local frame, title, text, scope = make("Dances, packs and potions")
		local list = frame:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		expect(list.FillDirection).to.equal(Enum.FillDirection.Vertical)
		expect(title.TextWrapped).to.equal(true)
		expect(text.TextWrapped).to.equal(true)
		expect(text.Visible).to.equal(true)
		scope:stop()
	end)

	it("puts it beside the title on a short screen, scrolling when it is too long", function()
		app.state:set("input.height", "short")
		local frame, title, text, scope = make("Dances, packs and potions")
		local list = frame:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		expect(list.FillDirection).to.equal(Enum.FillDirection.Horizontal)
		expect(title.TextWrapped).to.equal(false)
		-- the wrapping label steps aside for a marquee that fills the rest of the line
		expect(text.Visible).to.equal(false)
		local line: GuiObject? = nil
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") and child ~= title and child ~= text then
				line = child
			end
		end
		expect(line).to.be.ok()
		expect((line :: GuiObject).Visible).to.equal(true)
		local flex = (line :: GuiObject):FindFirstChildOfClass("UIFlexItem") :: UIFlexItem
		expect(flex.FlexMode).to.equal(Enum.UIFlexMode.Fill)
		-- and back when the screen grows
		app.state:set("input.height", "tall")
		Harness.flush()
		expect(list.FillDirection).to.equal(Enum.FillDirection.Vertical)
		expect(text.Visible).to.equal(true)
		expect((line :: GuiObject).Visible).to.equal(false)
		scope:stop()
	end)

	it("hides an empty description", function()
		local _, _, text, scope = make("")
		expect(text.Visible).to.equal(false)
		scope:stop()
	end)
end
