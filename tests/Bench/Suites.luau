--!strict
--[[
	The benchmark suites. Each suite builds fresh state in `setup` (untimed), does
	the measured work in `run`, and frees everything in `teardown` (untimed).
	`size` is the base workload; Run scales it (the spec smoke-runs at 1%).

	Times cover Lucy's own work: building instances, binding properties and running
	effects. Universal Styling resolves styles a few frames later, inside the engine,
	and is not part of any number here.
]]

export type Context = {
	Lucy: any,
	app: any,
	gui: Instance,
}

export type State = { [string]: any }

export type Suite = {
	name: string,
	group: string,
	size: number,
	description: string,
	setup: (ctx: Context, n: number) -> State,
	run: (state: State) -> (),
	teardown: ((state: State) -> ())?,
}

local function rows(n: number, from: number?): { { id: number, name: string } }
	local start = from or 1
	local list = table.create(n)
	for i = start, start + n - 1 do
		table.insert(list, { id = i, name = `Row {i}` })
	end
	return list
end

local function holder(ctx: Context): Frame
	local frame = Instance.new("Frame")
	frame.Name = "BenchHolder"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = ctx.gui
	return frame
end

-- A keyed list of TextLabels inside a ScrollingFrame, the shape of a shop or inventory.
local function mountList(Lucy: any, items: any, parent: Instance)
	return Lucy.new("ScrollingFrame")({
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
		Lucy.new("UIListLayout")({}),
		Lucy.each(items, function(item: any, index: any)
			return Lucy.new("TextLabel")({
				Name = "Row",
				Size = UDim2.new(1, 0, 0, 24),
				Text = function()
					return `{index()}. {item.name}`
				end,
			})
		end, {
			key = function(item: any)
				return item.id
			end,
		}),
	})
end

-- Setup for the list suites: a mounted list of n rows held in a ref.
local function mountedList(ctx: Context, n: number): State
	local Lucy = ctx.Lucy
	local items = Lucy.ref(rows(n))
	local scope = Lucy.effectScope(true)
	local root = holder(ctx)
	scope:run(function()
		mountList(Lucy, items, root)
	end)
	return { Lucy = Lucy, items = items, scope = scope, root = root, n = n }
end

local function stop(state: State)
	if state.scope then
		state.scope:stop()
	end
	if state.root then
		state.root:Destroy()
	end
end

local suites: { Suite } = {
	{
		name = "Mount a keyed list",
		group = "Lists",
		size = 1000,
		description = "Build a ScrollingFrame with one bound TextLabel per row.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			return {
				Lucy = Lucy,
				items = Lucy.ref(rows(n)),
				scope = Lucy.effectScope(true),
				root = holder(ctx),
			}
		end,
		run = function(state)
			state.scope:run(function()
				mountList(state.Lucy, state.items, state.root)
			end)
		end,
		teardown = stop,
	},
	{
		name = "Edit 100 rows, one write each",
		group = "Lists",
		size = 1000,
		description = "A reactive list; change the name of 100 different rows, unbatched.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			local data = Lucy.reactive({ rows = rows(n) })
			local scope = Lucy.effectScope(true)
			local root = holder(ctx)
			scope:run(function()
				mountList(Lucy, function()
					return data.rows
				end, root)
			end)
			return { data = data, scope = scope, root = root, n = n }
		end,
		run = function(state)
			local list = state.data.rows
			local step = math.max(1, state.n // 100)
			for i = 1, state.n, step do
				list[i].name = "Edited"
			end
		end,
		teardown = stop,
	},
	{
		name = "Reverse a keyed list",
		group = "Lists",
		size = 1000,
		description = "Replace the list with its reverse; every row is kept and moved.",
		setup = mountedList,
		run = function(state)
			local current = state.Lucy.peek(state.items)
			local reversed = table.create(#current)
			for i = #current, 1, -1 do
				table.insert(reversed, current[i])
			end
			state.items(reversed)
		end,
		teardown = stop,
	},
	{
		name = "Append 100 rows",
		group = "Lists",
		size = 1000,
		description = "Add 100 new rows to the end of a mounted list.",
		setup = mountedList,
		run = function(state)
			local current = state.Lucy.peek(state.items)
			local extra = math.max(1, state.n // 10)
			local nextList = table.clone(current)
			for _, row in rows(extra, state.n + 1) do
				table.insert(nextList, row)
			end
			state.items(nextList)
		end,
		teardown = stop,
	},
	{
		name = "Clear a keyed list",
		group = "Lists",
		size = 1000,
		description = "Set the list to empty; every row is destroyed.",
		setup = mountedList,
		run = function(state)
			state.items({})
		end,
		teardown = stop,
	},
	{
		name = "Destroy a mounted list",
		group = "Lists",
		size = 1000,
		description = "Stop the scope that owns the list: bindings, effects and instances.",
		setup = mountedList,
		run = function(state)
			state.scope:stop()
			state.scope = nil
		end,
		teardown = stop,
	},
	{
		name = "HUD frame: 50 values, 200 labels",
		group = "HUD",
		size = 200,
		description = "200 labels each read two of 50 refs; write all 50 in one batch.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			local values = {}
			for i = 1, 50 do
				values[i] = Lucy.ref(0)
			end
			local scope = Lucy.effectScope(true)
			local root = holder(ctx)
			scope:run(function()
				for i = 1, n do
					local a = values[(i - 1) % 50 + 1]
					local b = values[(i * 7) % 50 + 1]
					Lucy.new("TextLabel")({
						Name = "Stat",
						Size = UDim2.fromOffset(120, 20),
						Text = function()
							return `{a()} / {b()}`
						end,
						Parent = root,
					})
				end
			end)
			return { Lucy = Lucy, values = values, scope = scope, root = root, tick = 0 }
		end,
		run = function(state)
			state.tick += 1
			local tick = state.tick
			state.Lucy.batch(function()
				for i, value in state.values do
					value(tick * 100 + i)
				end
			end)
		end,
		teardown = stop,
	},
	{
		name = "One value, 1,000 readers",
		group = "HUD",
		size = 1000,
		description = "1,000 labels bound to one ref; write it once.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			local coins = Lucy.ref(0)
			local scope = Lucy.effectScope(true)
			local root = holder(ctx)
			scope:run(function()
				for _ = 1, n do
					Lucy.new("TextLabel")({
						Name = "Coins",
						Text = function()
							return tostring(coins())
						end,
						Parent = root,
					})
				end
			end)
			return { coins = coins, scope = scope, root = root }
		end,
		run = function(state)
			state.coins(state.coins() + 1)
		end,
		teardown = stop,
	},
	{
		name = "Mount Buttons",
		group = "Components",
		size = 100,
		description = "Lucy.Button.new with reactive text, in a Stack.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			return {
				Lucy = Lucy,
				app = ctx.app,
				n = n,
				label = Lucy.ref("Buy"),
				scope = Lucy.effectScope(true),
				root = holder(ctx),
			}
		end,
		run = function(state)
			local Lucy = state.Lucy
			state.scope:run(function()
				for i = 1, state.n do
					Lucy.Button.new({
						app = state.app,
						Parent = state.root,
						text = function()
							return `{state.label()} {i}`
						end,
					})
				end
			end)
		end,
		teardown = stop,
	},
	{
		name = "Toggle Switches",
		group = "Components",
		size = 100,
		description = "Switches bound two-way to one ref; flip it.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			local on = Lucy.ref(false)
			local scope = Lucy.effectScope(true)
			local root = holder(ctx)
			scope:run(function()
				for i = 1, n do
					Lucy.Switch.new({ app = ctx.app, Parent = root, label = `Option {i}`, checked = on })
				end
			end)
			return { on = on, scope = scope, root = root }
		end,
		run = function(state)
			state.on(not state.on())
		end,
		teardown = stop,
	},
	{
		name = "Ref to computed to effect",
		group = "Reactive core",
		size = 10000,
		description = "Write a ref read by a computed read by an effect, n times.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			local source = Lucy.ref(0)
			local double = Lucy.computed(function()
				return source() * 2
			end)
			local scope = Lucy.effectScope(true)
			local sink = { total = 0 }
			scope:run(function()
				Lucy.watchEffect(function()
					sink.total += double()
				end)
			end)
			return { source = source, scope = scope, n = n }
		end,
		run = function(state)
			local source = state.source
			for i = 1, state.n do
				source(i)
			end
		end,
		teardown = stop,
	},
	{
		name = "Diamond: 1 ref, 1,000 computeds",
		group = "Reactive core",
		size = 1000,
		description = "One effect sums n computeds that all read one ref; write it once.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			local source = Lucy.ref(0)
			local nodes = table.create(n)
			for i = 1, n do
				nodes[i] = Lucy.computed(function()
					return source() + i
				end)
			end
			local scope = Lucy.effectScope(true)
			local sink = { total = 0 }
			scope:run(function()
				Lucy.watchEffect(function()
					local total = 0
					for _, node in nodes do
						total += node()
					end
					sink.total = total
				end)
			end)
			return { source = source, scope = scope, sink = sink }
		end,
		run = function(state)
			state.source(state.source() + 1)
		end,
		teardown = stop,
	},
	{
		name = "Mount 1,000 bound effects",
		group = "Reactive core",
		size = 1000,
		description = "Create n effects that each read one ref, inside a scope.",
		setup = function(ctx, n)
			local Lucy = ctx.Lucy
			return { Lucy = Lucy, n = n, source = Lucy.ref(0), scope = Lucy.effectScope(true) }
		end,
		run = function(state)
			local Lucy = state.Lucy
			local source = state.source
			state.scope:run(function()
				for _ = 1, state.n do
					Lucy.watchEffect(function()
						source()
					end)
				end
			end)
		end,
		teardown = stop,
	},
}

return suites
