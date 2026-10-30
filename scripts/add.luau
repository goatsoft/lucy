--[[
	Lucy component installer.

	Copies components (and what they depend on) into your project as plain source
	you own and can edit. Core is always copied. An init.luau index listing what
	is installed is regenerated each time.

		lune run <lucy>/scripts/add -- button dialog --out src/shared/Lucy
		lune run <lucy>/scripts/add -- --all --out src/shared/Lucy --specs
		lune run <lucy>/scripts/add -- --list
		lune run <lucy>/scripts/add -- --check

	Options:
		--out <dir>     destination (default: src/shared/Lucy)
		--from <dir>    Lucy checkout (default: $LUCY_HOME, else the current directory)
		--all           every component
		--specs         also copy the *.spec.luau tests and the test harness
		--overwrite     replace files that already exist (default: keep your edits)
		--dry-run       print what would happen
		--list          list available components
		--check         install everything into a temporary folder and check that
		                every require resolves (CI runs this)

	Nothing here is listed by hand: core is every file in src/ outside Components/,
	a component's dependencies are the components it requires, and init.luau is
	src/init.luau with the components that are not installed left out.
	registry.json only holds each component's description.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local function fail(message: string): never
	print("error: " .. message)
	process.exit(1)
	error(message)
end

local function join(...: string): string
	local parts = {}
	for _, part in { ... } do
		if part ~= "" then
			table.insert(parts, (string.gsub(part, "/+$", "")))
		end
	end
	return table.concat(parts, "/")
end

local function dirname(path: string): string
	return string.match(path, "^(.*)/[^/]*$") or "."
end

-- "ScrollArea" -> "scroll-area"
local function kebab(module: string): string
	return string.lower((string.gsub(module, "(%l)(%u)", "%1-%2")))
end

-- Arguments -----------------------------------------------------------------

local args = process.args
local options: { [string]: any } =
	{ out = "src/shared/Lucy", from = process.env.LUCY_HOME or process.cwd, names = {} }
local i = 1
while i <= #args do
	local arg = args[i]
	if arg == "--out" or arg == "--from" then
		options[string.sub(arg, 3)] = args[i + 1] or fail(`{arg} needs a value`)
		i += 1
	elseif
		arg == "--all"
		or arg == "--specs"
		or arg == "--overwrite"
		or arg == "--list"
		or arg == "--check"
	then
		options[string.sub(arg, 3)] = true
	elseif arg == "--dry-run" then
		options.dryRun = true
	elseif arg == "--" then
		-- separator from `lune run`
	elseif string.sub(arg, 1, 2) == "--" then
		fail(`unknown option {arg}`)
	else
		table.insert(options.names, string.lower(arg))
	end
	i += 1
end

local source = join(options.from, "src")
if not fs.isFile(join(source, "init.luau")) then
	fail(`no src/init.luau in {options.from} (pass --from or set LUCY_HOME)`)
end
local registryPath = join(options.from, "registry.json")
local registry = if fs.isFile(registryPath) then serde.decode("json", fs.readFile(registryPath)) else {}
local descriptions: { [string]: string } = registry.components or {}

-- What src holds ----------------------------------------------------------------

-- Every file under `dir` (relative to `source`), sorted.
local function walk(dir: string, out: { string })
	local full = join(source, dir)
	local entries = fs.readDir(full)
	table.sort(entries)
	for _, name in entries do
		local relative = if dir == "" then name else `{dir}/{name}`
		if fs.isDir(join(source, relative)) then
			walk(relative, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, relative)
		end
	end
end
local files = {}
walk("", files)

local function isSpec(path: string): boolean
	return string.match(path, "%.spec%.luau$") ~= nil
end

-- Components: name -> { module, dependencies }
type Component = { module: string, dependencies: { string } }
local components: { [string]: Component } = {}
local byModule: { [string]: string } = {}
for _, path in files do
	local module = string.match(path, "^Components/(%w+)%.luau$")
	if module then
		local name = kebab(module)
		components[name] = { module = module, dependencies = {} }
		byModule[module] = name
	end
end
for name, component in components do
	local text = fs.readFile(join(source, "Components", component.module .. ".luau"))
	for module in string.gmatch(text, "require%(script%.Parent%.(%w+)%)") do
		local dependency = byModule[module]
		if dependency and dependency ~= name and not table.find(component.dependencies, dependency) then
			table.insert(component.dependencies, dependency)
		end
	end
	table.sort(component.dependencies)
end

-- Core: everything outside Components/ and the index. The harness only comes with specs.
local core, coreSpecs = {}, {}
for _, path in files do
	if path ~= "init.luau" and not string.match(path, "^Components/") then
		if isSpec(path) then
			table.insert(coreSpecs, path)
		elseif string.match(path, "^Testing/") then
			table.insert(coreSpecs, path)
		else
			table.insert(core, path)
		end
	end
end

-- List ---------------------------------------------------------------------------

if options.list then
	local names = {}
	for name in components do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local needs = components[name].dependencies
		local suffix = if #needs > 0 then ` (with {table.concat(needs, ", ")})` else ""
		print(string.format("  %-14s %s%s", name, descriptions[name] or "", suffix))
	end
	return
end

-- Check: every component has a description, and a full install resolves -----------

if options.check then
	options.all = true
	options.specs = true
	options.overwrite = true
	options.dryRun = false
	local base = process.env.TMPDIR or "/tmp"
	options.out = join(base, `lucy-add-check-{os.time()}-{math.random(1, 1e6)}`)
	for name in components do
		if not descriptions[name] then
			fail(`registry.json has no description for component "{name}"`)
		end
	end
	for name in descriptions do
		if not components[name] then
			fail(`registry.json describes "{name}", but src/Components has no such component`)
		end
	end
end

if options.all then
	for name in components do
		table.insert(options.names, name)
	end
	table.sort(options.names)
end
if #options.names == 0 then
	fail("name at least one component, or pass --all (see --list)")
end

-- Resolve dependencies --------------------------------------------------------

local selected, order = {}, {}
local function visit(raw: string, from: string?)
	-- "scrollarea", "scroll-area" and "ScrollArea" all name the same component.
	local name = if components[raw] then raw else byModule[raw]
	if not name then
		for candidate, component in components do
			if string.lower(component.module) == string.lower(raw) then
				name = candidate
			end
		end
	end
	if not name then
		fail(`unknown component "{raw}"` .. (if from then ` (needed by {from})` else "") .. " (see --list)")
	end
	local key = name :: string
	if selected[key] then
		return
	end
	selected[key] = true
	for _, dependency in components[key].dependencies do
		visit(dependency, key)
	end
	table.insert(order, key)
end
for _, name in options.names do
	visit(name)
end

-- Copy -------------------------------------------------------------------------

local copied, kept = 0, 0
local function copy(relative: string)
	local from = join(source, relative)
	local to = join(options.out, relative)
	if fs.isFile(to) and not options.overwrite then
		kept += 1
		return
	end
	if options.dryRun then
		print("  would copy " .. relative)
	else
		fs.writeDir(dirname(to))
		fs.writeFile(to, fs.readFile(from))
	end
	copied += 1
end

for _, file in core do
	copy(file)
end
if options.specs then
	for _, file in coreSpecs do
		copy(file)
	end
end
for _, name in order do
	local module = components[name].module
	copy(`Components/{module}.luau`)
	local spec = `Components/{module}.spec.luau`
	if options.specs and fs.isFile(join(source, spec)) then
		copy(spec)
	end
end

-- The index: src/init.luau with uninstalled components left out ----------------------

local function installed(): { [string]: boolean }
	local out = {}
	local dir = join(options.out, "Components")
	if fs.isDir(dir) then
		for _, file in fs.readDir(dir) do
			local module = string.match(file, "^(%w+)%.luau$")
			if module then
				out[module] = true
			end
		end
	end
	for _, name in order do
		out[components[name].module] = true
	end
	return out
end

local have = installed()
local lines = {}
local header = false
for line in string.gmatch(fs.readFile(join(source, "init.luau")) .. "\n", "([^\n]*)\n") do
	local module = string.match(line, "^%s*(%w+) = require%(Components%.(%w+)%),?$")
	if module and not have[module] then
		continue
	end
	table.insert(lines, line)
	if not header and line == "--!strict" then
		table.insert(
			lines,
			"-- Made by Lucy's scripts/add from src/init.luau: re-run it after adding components."
		)
		header = true
	end
end
while lines[#lines] == "" do
	table.remove(lines)
end
table.insert(lines, "")

if options.dryRun then
	print("  would write init.luau")
else
	fs.writeDir(options.out)
	fs.writeFile(join(options.out, "init.luau"), table.concat(lines, "\n"))
end

-- Check that every require in the install points at something that is there -------------

-- The instance path a module's `script` is, relative to the install root.
local function scriptPath(relative: string): { string }
	local parts = string.split(relative, "/")
	local last = parts[#parts]
	if last == "init.luau" then
		table.remove(parts)
	else
		parts[#parts] = string.gsub(last, "%.luau$", "")
	end
	return parts
end

local function exists(parts: { string }): boolean
	local path = join(options.out, table.concat(parts, "/"))
	return fs.isFile(path .. ".luau") or fs.isFile(join(path, "init.luau"))
end

local function checkInstall(): { string }
	local problems = {}
	local all = {}
	local function collect(dir: string)
		for _, name in fs.readDir(join(options.out, dir)) do
			local relative = if dir == "" then name else `{dir}/{name}`
			if fs.isDir(join(options.out, relative)) then
				collect(relative)
			elseif string.match(name, "%.luau$") then
				table.insert(all, relative)
			end
		end
	end
	collect("")
	for _, relative in all do
		local text = fs.readFile(join(options.out, relative))
		-- Locals that name a child of script, as init.luau does (local Core = script.Core).
		local aliases: { [string]: string } = {}
		for alias, child in string.gmatch(text, "local (%w+) = script%.(%w+)\n") do
			aliases[alias] = child
		end
		for chain in string.gmatch(text, "require%(([%w%.]+)%)") do
			local segments = string.split(chain, ".")
			local first = table.remove(segments, 1) :: string
			local path: { string }?
			if first == "script" then
				path = scriptPath(relative)
			elseif aliases[first] then
				path = scriptPath(relative)
				table.insert(path :: { string }, aliases[first])
			end
			if path then
				local resolved = table.clone(path)
				local ok = true
				for _, segment in segments do
					if segment == "Parent" then
						if #resolved == 0 then
							ok = false
							break
						end
						table.remove(resolved)
					else
						table.insert(resolved, segment)
					end
				end
				if not ok or not exists(resolved) then
					table.insert(problems, `{relative}: require({chain}) finds nothing`)
				end
			end
		end
	end
	return problems
end

if options.check then
	local problems = checkInstall()
	fs.removeDir(options.out)
	if #problems > 0 then
		fail("the full install does not load:\n  " .. table.concat(problems, "\n  "))
	end
	local count = 0
	for _ in components do
		count += 1
	end
	print(`Lucy: {count} components, {#core} core files; every require resolves`)
	return
end

print(`Lucy: {copied} file(s) copied, {kept} kept (use --overwrite to replace) into {options.out}`)
print("Installed: " .. table.concat(order, ", "))
