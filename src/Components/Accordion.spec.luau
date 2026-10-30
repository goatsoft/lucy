return function()
	local Accordion = require(script.Parent.Accordion)
	local Composables = require(script.Parent.Parent.Composables)
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
		{ value = "audio", text = "Audio" },
		{ value = "video", text = "Video" },
		{ value = "controls", text = "Controls" },
	}

	local function opened(a): string
		local out = {}
		for _, item in ITEMS do
			if a.sections[item.value]:get("open") then
				table.insert(out, item.value)
			end
		end
		return table.concat(out, ",")
	end

	it("is a stack of collapsibles, all closed by default", function()
		local a = Accordion.new({ app = app, Parent = gui, items = ITEMS })
		expect(a.Instance:HasTag("ui-accordion")).to.equal(true)
		expect(a:get("value")).to.equal(false)
		expect(opened(a)).to.equal("")
		expect(a.sections.video.label.Text).to.equal("Video")
		expect(a.sections.audio.Instance.LayoutOrder < a.sections.video.Instance.LayoutOrder).to.equal(true)
	end)

	it("single: opening one closes the others, and pressing the open one closes it", function()
		local a = Accordion.new({ app = app, Parent = gui, items = ITEMS, value = "audio" })
		expect(opened(a)).to.equal("audio")
		a:toggle("video")
		expect(a:get("value")).to.equal("video")
		expect(opened(a)).to.equal("video")
		a.sections.video:toggle()
		expect(a:get("value")).to.equal(false)
		expect(opened(a)).to.equal("")
	end)

	it("multiple: any number stay open, the value lists them in item order", function()
		local a = Accordion.new({ app = app, Parent = gui, items = ITEMS, type = "multiple" })
		expect(#a:get("value")).to.equal(0)
		a:toggle("controls")
		a:toggle("audio")
		expect(opened(a)).to.equal("audio,controls")
		expect(table.concat(a:get("value"), ",")).to.equal("audio,controls")
		a:toggle("controls")
		expect(table.concat(a:get("value"), ",")).to.equal("audio")
		a:set("value", { "video" })
		expect(opened(a)).to.equal("video")
	end)

	it("rejects an unknown type", function()
		expect(function()
			Accordion.new({ app = app, Parent = gui, items = ITEMS, type = "some" })
		end).to.throw()
	end)

	it("keeps the value in step with a ref and reports changes", function()
		local value = Reactive.ref("audio" :: any)
		local seen = {}
		local a = Accordion.new({
			app = app,
			Parent = gui,
			items = ITEMS,
			value = value,
			onValueChange = function(new)
				table.insert(seen, tostring(new))
			end,
		})
		a:toggle("video")
		expect(value()).to.equal("video")
		value("controls")
		expect(opened(a)).to.equal("controls")
		expect(table.concat(seen, ",")).to.equal("video,controls")
	end)

	it("passes variant and disabled to its sections", function()
		local a = Accordion.new({
			app = app,
			Parent = gui,
			items = { { value = "a", text = "A" }, { value = "b", text = "B", disabled = true } },
			variant = "details",
		})
		expect(a.sections.a:get("variant")).to.equal("details")
		expect(a.sections.a:get("disabled")).to.equal(false)
		expect(a.sections.b:get("disabled")).to.equal(true)
		a:set("disabled", true)
		expect(a.sections.a:get("disabled")).to.equal(true)
		a:toggle("a")
		expect(a:get("value")).to.equal(false)
	end)

	it("emits one toggle per press, with the open state", function()
		local calls = {}
		local scope = Reactive.effectScope(true)
		local a = scope:run(function()
			Composables.useUiSound(app, {
				toggle = function(_, value)
					table.insert(calls, tostring(value))
				end,
			})
			return Accordion.new({ app = app, Parent = gui, items = ITEMS })
		end)
		a:toggle("audio")
		a:toggle("video")
		a:toggle("video")
		a:set("value", "audio")
		expect(table.concat(calls, ",")).to.equal("true,true,false")
		scope:stop()
	end)

	it("opens a section when Enter is pressed on its header", function()
		local a = Accordion.new({ app = app, Parent = gui, items = ITEMS })
		app.input:focus(a.sections.controls.header)
		app.input:activate()
		expect(a:get("value")).to.equal("controls")
	end)
end
