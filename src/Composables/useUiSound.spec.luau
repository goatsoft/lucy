return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app()
	end)
	afterEach(function()
		cleanup()
	end)

	describe("useUiSound", function()
		local Lucy = require(script.Parent.Parent)

		-- Records every call as "event:value".
		local function recorder()
			local calls = {}
			local function on(name: string)
				return function(_handle: any, value: any)
					table.insert(calls, if value == nil then name else `{name}:{tostring(value)}`)
				end
			end
			return calls, on
		end

		it("calls the game's function with the component that emitted", function()
			local scope = Reactive.effectScope(true)
			local got
			local button = scope:run(function()
				Composables.useUiSound(app, {
					activate = function(handle)
						got = handle
					end,
				})
				return Lucy.Button.new({ app = app })
			end)
			button:click()
			expect(got).to.equal(button)
			scope:stop()
		end)

		it("emits toggle, open and close with their value", function()
			local calls, on = recorder()
			local scope = Reactive.effectScope(true)
			local switch, checkbox, dialog = scope:run(function()
				Composables.useUiSound(app, { toggle = on("toggle"), open = on("open"), close = on("close") })
				return Lucy.Switch.new({ app = app }),
					Lucy.Checkbox.new({ app = app }),
					Lucy.Dialog.new({ app = app })
			end)
			switch:toggle()
			checkbox:toggle()
			checkbox:toggle()
			dialog:open()
			dialog:close()
			expect(table.concat(calls, " ")).to.equal("toggle:true toggle:true toggle:false open close")
			scope:stop()
		end)

		it("uses the closest map that names the event, and false silences it", function()
			local calls, on = recorder()
			local outer = Reactive.effectScope(true)
			local button, switch, quiet = outer:run(function()
				Composables.useUiSound(app, { activate = on("outer"), toggle = on("toggle") })
				local inner = Reactive.effectScope()
				local b, s = inner:run(function()
					Composables.useUiSound(app, { activate = on("inner") })
					return Lucy.Button.new({ app = app }), Lucy.Switch.new({ app = app })
				end)
				local silent = Reactive.effectScope()
				local q = silent:run(function()
					Composables.useUiSound(app, { activate = false })
					return Lucy.Button.new({ app = app })
				end)
				return b, s, q
			end)
			button:click()
			switch:toggle()
			quiet:click()
			expect(table.concat(calls, " ")).to.equal("inner toggle:true")
			outer:stop()
		end)

		it("stops when its owner stops", function()
			local calls, on = recorder()
			local sounds = Reactive.effectScope(true)
			sounds:run(function()
				Composables.useUiSound(app, { activate = on("activate") })
			end)
			local button = Lucy.Button.new({ app = app })
			button:click()
			sounds:stop()
			task.wait(0.06) -- past the double click guard
			button:click()
			expect(table.concat(calls, " ")).to.equal("activate")
			button:destroy()
		end)

		it("covers components made with no owner from a top-level scope", function()
			local calls, on = recorder()
			local sounds = Reactive.effectScope(true)
			sounds:run(function()
				Composables.useUiSound(app, { activate = on("activate") })
			end)
			local button = Lucy.Button.new({ app = app })
			button:click()
			expect(table.concat(calls, " ")).to.equal("activate")
			button:destroy()
			sounds:stop()
		end)

		it("is silenced per component with sound = false", function()
			local calls, on = recorder()
			local scope = Reactive.effectScope(true)
			local button = scope:run(function()
				Composables.useUiSound(app, { activate = on("activate") })
				return Lucy.Button.new({ app = app, sound = false })
			end)
			button:click()
			expect(#calls).to.equal(0)
			scope:stop()
		end)

		it("keeps a failing sound function from breaking the click", function()
			local clicked = false
			local scope = Reactive.effectScope(true)
			local button = scope:run(function()
				Composables.useUiSound(app, {
					activate = function()
						error("boom")
					end,
				})
				return Lucy.Button.new({
					app = app,
					onClick = function()
						clicked = true
					end,
				})
			end)
			button:click()
			expect(clicked).to.equal(true)
			scope:stop()
		end)
	end)
end
