--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Asks the server with app.server:call and keeps the answer as state, for a panel that
	shows what the server knows: a leaderboard, a shop's stock, a friend's profile.
	Returns { data, loading, error, refresh }.

		local board = Lucy.useRequest(app, "boards.get", function()
			return tab(), period()          -- read reactively: a new tab asks again
		end, { enabled = open, every = 30 })
		board.data()      -- the handler's answer, nil until the first one
		board.loading()   -- true while a call is out
		board.error()     -- the last call's error message, nil once one succeeds
		board.refresh()   -- ask again now, keeping the answer it has meanwhile

	`args` is a getter returning the call's arguments, a list of them, or nil for none.
	When the getter's reads change it asks again; data clears straight away, so a new tab
	never shows the old tab's rows, unless options.keep. Only the newest call's answer
	lands: one that comes late, after the arguments moved on or the owner stopped, is
	dropped. An error keeps the data it had.

	options:
		enabled  a boolean, ref or getter: no calls while false (a closed dialog)
		every    seconds: asks again this often while enabled, keeping the data
		keep     true to keep the last answer while the next arguments load
]]
type RequestOptions = { enabled: Reactive.MaybeRef<boolean>?, every: number?, keep: boolean? }

local function useRequest(
	app: any,
	name: string,
	args: any?,
	options: RequestOptions?
): {
	data: Reactive.Computed<any>,
	loading: Reactive.Computed<boolean>,
	error: Reactive.Computed<string?>,
	refresh: () -> (),
}
	requireOwner("useRequest")
	local opts: RequestOptions = options or {}
	local answer = Reactive.ref(nil :: any)
	local busy = Reactive.ref(false)
	local failed = Reactive.ref(nil :: string?)
	-- Each call takes the next number; only the newest one's answer lands
	local latest = 0
	local stopped = false
	local current: { n: number, [number]: any }? = nil

	local function ask(pack: { n: number, [number]: any }, clear: boolean)
		latest += 1
		local mine = latest
		Reactive.batch(function()
			if clear then
				answer(nil)
			end
			busy(true)
		end)
		task.spawn(function()
			local ok, result = pcall(function()
				return app.server:call(name, table.unpack(pack, 1, pack.n))
			end)
			if stopped or mine ~= latest then
				return
			end
			Reactive.batch(function()
				busy(false)
				if ok then
					answer(result)
					failed(nil)
				else
					failed(tostring(result))
				end
			end)
		end)
	end

	local function argsNow(): { n: number, [number]: any }
		if type(args) == "function" then
			return table.pack(args())
		elseif type(args) == "table" then
			return table.pack(table.unpack(args))
		end
		return { n = 0 }
	end

	Reactive.watchEffect(function(onCleanup)
		local enabled = opts.enabled == nil or Reactive.toValue(opts.enabled) == true
		local pack = argsNow()
		if not enabled then
			current = nil
			latest += 1 -- a call still out no longer lands
			Reactive.untrack(busy, false)
			return
		end
		current = pack
		Reactive.untrack(ask, pack, not opts.keep)
		if opts.every then
			local every = opts.every
			local thread = task.spawn(function()
				while true do
					task.wait(every)
					if not Reactive.untrack(busy) then
						Reactive.untrack(ask, pack, false)
					end
				end
			end)
			onCleanup(function()
				task.cancel(thread)
			end)
		end
	end)
	Reactive.onCleanup(function()
		stopped = true
	end)

	return {
		data = Reactive.computed(function()
			return answer()
		end),
		loading = Reactive.computed(function()
			return busy()
		end),
		error = Reactive.computed(function()
			return failed()
		end),
		refresh = function()
			if current and not stopped then
				ask(current, false)
			end
		end,
	}
end

return useRequest
