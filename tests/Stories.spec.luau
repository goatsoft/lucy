--[[
	Every story in examples/stories mounts without errors, in both themes and on
	every device, and leaves nothing behind. Lucy and LucyExamples are looked up as
	siblings of this folder (ReplicatedStorage in the dev place).
]]
return function()
	local root = script.Parent.Parent
	local package = root:FindFirstChild("Lucy")
	local examples = root:FindFirstChild("LucyExamples")
	if not package or not examples then
		return
	end

	local Lucy = require(package)
	local Harness = require(package.Testing.Harness)
	local Preview = Lucy.Preview
	local Context = require(package.Core.Context)
	local stories = Preview.find(examples)
	local parent = Harness.guiParent()

	it("finds the stories", function()
		expect(#stories >= 15).to.equal(true)
		for _, story in stories do
			expect(story.loadError).to.equal(nil)
		end
	end)

	local function leftovers(): { string }
		local out = {}
		for _, child in parent:GetChildren() do
			if string.sub(child.Name, 1, 12) == "LucyPreview_" then
				table.insert(out, child.Name)
			end
		end
		return out
	end

	for _, story in stories do
		it(`mounts {story.group}/{story.title} and cleans up`, function()
			for _, setup in
				{
					{ theme = "dark", device = "desktop" },
					{ theme = "light", device = "mobile" },
					{ theme = "dark", device = "console" },
				}
			do
				local before = Context.getCurrent()
				local mounted =
					Preview.mount(story, { parent = parent, theme = setup.theme, device = setup.device })
				expect(mounted.error).to.equal(nil)
				-- Every control can be written without errors.
				for _, control in Preview.controlsOf(story) do
					local value = if control.kind == "boolean"
						then not control.default
						elseif
							control.kind == "choice"
						then (control.options :: { any })[#(control.options :: { any })]
						elseif control.kind == "number" then control.max or control.default + 1
						else "changed"
					mounted:set(control.name, value)
				end
				mounted:destroy()
				expect(#leftovers()).to.equal(0)
				expect(Context.getCurrent()).to.equal(before)
			end
		end)
	end
end
