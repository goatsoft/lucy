return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)

	describe("useRequest", function()
		-- A server whose calls wait until the spec answers them, in any order.
		local function fakeServer()
			local server =
				{ calls = {} :: { { name: string, args: { n: number, [number]: any }, thread: thread } } }
			function server.call(_self: any, name: string, ...: any): any
				local call = { name = name, args = table.pack(...), thread = coroutine.running() }
				table.insert(server.calls, call)
				local ok, value = coroutine.yield()
				if not ok then
					error(value, 0)
				end
				return value
			end
			-- Answers call `index` (the oldest still waiting by default)
			function server.answer(index: number, value: any)
				local call = server.calls[index]
				task.spawn(call.thread, true, value)
			end
			function server.fail(index: number, message: string)
				task.spawn(server.calls[index].thread, false, message)
			end
			return server
		end

		local server, fakeApp
		beforeEach(function()
			server = fakeServer()
			fakeApp = { server = server }
		end)

		it("needs an owner", function()
			expect(function()
				Composables.useRequest(fakeApp, "boards.get")
			end).to.throw()
		end)

		it("calls the server, loading until the answer comes", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", function()
					return "combo", "week"
				end)
			end)
			expect(#server.calls).to.equal(1)
			expect(server.calls[1].name).to.equal("boards.get")
			expect(server.calls[1].args[1]).to.equal("combo")
			expect(server.calls[1].args[2]).to.equal("week")
			expect(request.loading()).to.equal(true)
			expect(request.data()).to.equal(nil)
			server.answer(1, { rows = { 1, 2 } })
			expect(request.loading()).to.equal(false)
			expect(#request.data().rows).to.equal(2)
			expect(request.error()).to.equal(nil)
			scope:stop()
		end)

		it("calls again when an argument changes, and drops a late answer to the old one", function()
			local scope = Reactive.effectScope(true)
			local board = Reactive.ref("combo")
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", function()
					return board()
				end)
			end)
			server.answer(1, "combo board")
			expect(request.data()).to.equal("combo board")
			board("coins")
			expect(#server.calls).to.equal(2)
			expect(server.calls[2].args[1]).to.equal("coins")
			-- the old answer goes as soon as the question changes
			expect(request.data()).to.equal(nil)
			expect(request.loading()).to.equal(true)
			board("hype")
			server.answer(3, "hype board")
			server.answer(2, "coins board") -- late: the player has moved on
			expect(request.data()).to.equal("hype board")
			expect(request.loading()).to.equal(false)
			scope:stop()
		end)

		it("keeps the last answer while the next one loads, with keep", function()
			local scope = Reactive.effectScope(true)
			local board = Reactive.ref("combo")
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", function()
					return board()
				end, { keep = true })
			end)
			server.answer(1, "combo board")
			board("coins")
			expect(request.data()).to.equal("combo board")
			expect(request.loading()).to.equal(true)
			server.answer(2, "coins board")
			expect(request.data()).to.equal("coins board")
			scope:stop()
		end)

		it("reports an error and keeps what it had", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get")
			end)
			server.answer(1, "board")
			request.refresh()
			expect(request.loading()).to.equal(true)
			server.fail(2, "too many requests")
			expect(request.loading()).to.equal(false)
			expect(request.error()).to.equal("too many requests")
			expect(request.data()).to.equal("board")
			request.refresh()
			server.answer(3, "board again")
			expect(request.error()).to.equal(nil)
			scope:stop()
		end)

		it("refreshes on demand, keeping the answer it has meanwhile", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get")
			end)
			server.answer(1, "board")
			request.refresh()
			expect(#server.calls).to.equal(2)
			expect(request.data()).to.equal("board")
			server.answer(2, "newer board")
			expect(request.data()).to.equal("newer board")
			scope:stop()
		end)

		it("waits while enabled is false", function()
			local scope = Reactive.effectScope(true)
			local open = Reactive.ref(false)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", nil, { enabled = open })
			end)
			expect(#server.calls).to.equal(0)
			expect(request.loading()).to.equal(false)
			request.refresh()
			expect(#server.calls).to.equal(0)
			open(true)
			expect(#server.calls).to.equal(1)
			scope:stop()
		end)

		it("asks again every few seconds, with every", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get", nil, { every = 0.05 })
			end)
			server.answer(1, "board")
			task.wait(0.08)
			expect(#server.calls).to.equal(2)
			expect(request.loading()).to.equal(true)
			expect(request.data()).to.equal("board")
			server.answer(2, "board 2")
			scope:stop()
			task.wait(0.1)
			expect(#server.calls).to.equal(2)
		end)

		it("drops an answer that comes after its owner stopped", function()
			local scope = Reactive.effectScope(true)
			local request
			scope:run(function()
				request = Composables.useRequest(fakeApp, "boards.get")
			end)
			scope:stop()
			server.answer(1, "board")
			expect(request.data()).to.equal(nil)
		end)
	end)
end
