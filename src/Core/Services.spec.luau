return function()
	local Services = require(script.Parent.Services)

	local function quiet()
		local warned = {}
		local services = Services.new({
			warn = function(message)
				table.insert(warned, message)
			end,
		})
		return services, warned
	end

	it("starts every service after what it needs", function()
		local services = quiet()
		local log = {}
		local function make(name: string, needs: { string }?)
			return {
				name = name,
				needs = needs,
				init = function()
					table.insert(log, "init " .. name)
				end,
				start = function()
					table.insert(log, "start " .. name)
				end,
			}
		end
		services:add(make("Wallet", { "Profiles" }))
		services:add(make("Trades", { "Wallet", "Profiles" }))
		services:add(make("Profiles"))
		services:run()
		expect(table.concat(log, ",")).to.equal(
			"init Profiles,init Wallet,init Trades,start Profiles,start Wallet,start Trades"
		)
	end)

	it("names a missing need and a loop", function()
		local services = quiet()
		services:add({ name = "A", needs = { "Nope" } })
		expect(function()
			services:order()
		end).to.throw()

		local loop = quiet()
		loop:add({ name = "A", needs = { "B" } })
		loop:add({ name = "B", needs = { "A" } })
		local ok, err = pcall(function()
			loop:order()
		end)
		expect(ok).to.equal(false)
		expect(string.find(tostring(err), "loop", 1, true) ~= nil).to.equal(true)
	end)

	it("refuses two services with one name, and an init that yields", function()
		local services = quiet()
		services:add({ name = "A", init = function() end })
		expect(function()
			services:add({ name = "A", init = function() end })
		end).to.throw()

		local yielding = quiet()
		local resumed = false
		yielding:add({
			name = "Slow",
			init = function()
				task.wait()
				resumed = true
			end,
		})
		expect(function()
			yielding:run()
		end).to.throw()
		-- the init is stopped, not left to run after start up failed
		task.wait()
		task.wait()
		expect(resumed).to.equal(false)
	end)

	it("warns about a start that fails and starts the rest", function()
		local services, warned = quiet()
		local started = false
		services:add({
			name = "Broken",
			start = function()
				error("boom")
			end,
		})
		services:add({
			name = "Fine",
			start = function()
				started = true
			end,
		})
		services:run()
		expect(started).to.equal(true)
		expect(#warned).to.equal(1)
	end)

	it("gets a service by name and tells services from helpers", function()
		local services = quiet()
		local wallet = services:add({ name = "Wallet", init = function() end })
		expect(services:get("Wallet")).to.equal(wallet)
		expect(Services.isService({ start = function() end })).to.equal(true)
		expect(Services.isService({ sum = function() end })).to.equal(false)
		expect(Services.isService(42)).to.equal(false)
	end)
end
