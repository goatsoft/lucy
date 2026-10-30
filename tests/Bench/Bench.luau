--!strict
--[[
	A small benchmark harness. Each iteration runs setup (untimed), run (timed with
	os.clock) and teardown (untimed). Times are reported in milliseconds.

	heapKb is the growth of the Luau heap across `run`, read with gcinfo(). Roblox
	cannot force a collection, so it is a guide, not an exact allocation count. A
	collection during `run` makes the delta negative; those samples are dropped and
	the median of the rest is reported, or nil when none is left. Instance memory
	held by the engine is not included.
]]

export type Stats = {
	min: number,
	max: number,
	mean: number,
	median: number,
	p95: number,
}

export type Options = {
	setup: (() -> any)?,
	run: (state: any) -> (),
	teardown: ((state: any) -> ())?,
	warmup: number?,
	iterations: number?,
}

export type Measurement = {
	samples: { number },
	heapKb: number?,
	min: number,
	max: number,
	mean: number,
	median: number,
	p95: number,
}

export type Row = {
	name: string,
	group: string,
	size: number,
	median: number,
	p95: number,
	heapKb: number?,
	error: string?,
}

local Bench = {}

local function median(sorted: { number }): number
	local n = #sorted
	if n == 0 then
		return 0
	end
	if n % 2 == 1 then
		return sorted[(n + 1) // 2]
	end
	return (sorted[n // 2] + sorted[n // 2 + 1]) / 2
end

-- The median of the heap deltas a collection did not cut short, or nil.
function Bench.heap(deltas: { number }): number?
	local kept = {}
	for _, delta in deltas do
		if delta >= 0 then
			table.insert(kept, delta)
		end
	end
	if #kept == 0 then
		return nil
	end
	table.sort(kept)
	return median(kept)
end

function Bench.stats(samples: { number }): Stats
	local sorted = table.clone(samples)
	table.sort(sorted)
	local n = #sorted
	if n == 0 then
		return { min = 0, max = 0, mean = 0, median = 0, p95 = 0 }
	end
	local total = 0
	for _, value in sorted do
		total += value
	end
	return {
		min = sorted[1],
		max = sorted[n],
		mean = total / n,
		median = median(sorted),
		p95 = sorted[math.clamp(math.ceil(n * 0.95), 1, n)],
	}
end

function Bench.measure(options: Options): Measurement
	local warmup = options.warmup or 3
	local iterations = options.iterations or 15
	local setup = options.setup
	local run = options.run
	local teardown = options.teardown
	local samples: { number } = {}
	local heaps: { number } = {}

	for i = 1, warmup + iterations do
		local state = if setup then setup() else nil
		local heapBefore = gcinfo()
		local start = os.clock()
		run(state)
		local elapsed = os.clock() - start
		local heapAfter = gcinfo()
		if teardown then
			teardown(state)
		end
		if i > warmup then
			table.insert(samples, elapsed * 1000)
			table.insert(heaps, heapAfter - heapBefore)
		end
	end

	local s = Bench.stats(samples)
	return {
		samples = samples,
		heapKb = Bench.heap(heaps),
		min = s.min,
		max = s.max,
		mean = s.mean,
		median = s.median,
		p95 = s.p95,
	}
end

local function thousands(n: number): string
	local text = tostring(math.floor(n + 0.5))
	local out = text
	repeat
		local replaced
		out, replaced = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return out
end
Bench.thousands = thousands

local function fixed(n: number, places: number): string
	return string.format(`%.{places}f`, n)
end

-- A markdown table: one row per result, in the order given.
function Bench.markdown(rows: { Row }): string
	local lines = {
		"| Benchmark | Group | Size | Median (ms) | p95 (ms) | Heap (KB) |",
		"|---|---|---:|---:|---:|---:|",
	}
	for _, row in rows do
		local cells = {
			row.name,
			row.group,
			thousands(row.size),
			fixed(row.median, 2),
			fixed(row.p95, 2),
			if row.heapKb then fixed(row.heapKb, 0) else "n/a",
		}
		table.insert(lines, `| {table.concat(cells, " | ")} |`)
	end
	return table.concat(lines, "\n")
end

return Bench
