--!strict
--[[
	DialogueTree (ADR 0060): a pure Luau branching dialogue engine and data model
	that runs on both the server and the client.

	Trees are flat dictionaries of nodes keyed by node id (no deep nesting), so
	Branch and Bottleneck, Hub and Spokes, and Priority Stack / Router patterns
	all read cleanly and never suffer from combinatorial explosion:

		local tree = {
			id = "dj_booth",
			speaker = "dj_nova",
			entry = { "greet_vip", "greet_default" }, -- Priority Stack
			nodes = {
				greet_vip = {
					when = function(bb) return bb:get("vip") == true end,
					text = "Welcome back, {name}. Ready for a set?",
					next = "hub",
				},
				greet_default = {
					text = "Hey, welcome to Club Lucy.",
					onEnter = function(bb) bb:set("metNova", true) end,
					next = "hub",
				},
				hub = {
					text = "What can I do for you?",
					choices = {
						{ id = "tips", label = "Any tips?", next = "tips", once = true },
						{
							id = "vip_track",
							label = "Spin the VIP mix",
							next = "vip_done",
							when = function(bb) return bb:get("vip") == true end,
							locked = "disable",
							lockedReason = "VIP pass required",
							onSelect = function(bb) bb:fire("playVipMix") end,
						},
						{ id = "leave", label = "Catch you later.", close = true },
					},
				},
				tips = { text = "Hit notes on the beat to build your combo.", next = "hub" },
				vip_done = { text = "Dropping the VIP mix now!", isEnd = true },
			},
		}

		local runner = Lucy.DialogueTree.new(tree, blackboard)
		local snap = runner:start()
		runner:choose("tips")
]]

local Signal = require(script.Parent.Signal)

export type Blackboard = {
	get: (self: Blackboard, key: string) -> any,
	set: (self: Blackboard, key: string, value: any) -> (),
	has: ((self: Blackboard, key: string) -> boolean)?,
	fire: ((self: Blackboard, eventName: string, payload: any?) -> ())?,
	[any]: any,
}

export type Condition = string | (blackboard: Blackboard) -> boolean
export type Action = string | (blackboard: Blackboard) -> ()

export type Choice = {
	id: string,
	label: string,
	next: string?,
	close: boolean?,
	when: Condition?,
	locked: ("hide" | "disable")?,
	lockedReason: string?,
	once: boolean?,
	onSelect: Action?,
	variant: string?,
}

export type Node = {
	speaker: string?,
	text: string,
	audio: string?,
	animation: string?,
	mood: string?,
	meta: { [string]: any }?,
	when: Condition?,
	onEnter: Action?,
	onExit: Action?,
	next: string?,
	choices: { Choice }?,
	isEnd: boolean?,
}

export type Tree = {
	id: string,
	speaker: string?,
	entry: string | { string },
	canLeave: boolean?,
	nodes: { [string]: Node },
}

export type SnapshotChoice = {
	id: string,
	label: string,
	variant: string,
	disabled: boolean,
	lockedReason: string?,
}

export type Snapshot = {
	treeId: string,
	nodeId: string,
	speaker: string,
	text: string,
	audio: string?,
	animation: string?,
	mood: string?,
	meta: { [string]: any }?,
	canLeave: boolean,
	canAdvance: boolean,
	isEnd: boolean,
	choices: { SnapshotChoice },
}

export type Options = {
	conditions: { [string]: (blackboard: Blackboard) -> boolean }?,
	actions: { [string]: (blackboard: Blackboard) -> () }?,
}

export type Runner = {
	tree: Tree,
	blackboard: Blackboard,
	changed: Signal.Signal,
	ended: Signal.Signal,
	start: (self: Runner) -> Snapshot?,
	choose: (self: Runner, choiceId: string) -> (boolean, Snapshot?),
	advance: (self: Runner) -> (boolean, Snapshot?),
	close: (self: Runner) -> (),
	snapshot: (self: Runner) -> Snapshot?,
	nodeId: (self: Runner) -> string?,
	active: (self: Runner) -> boolean,
}

local DialogueTree = {}
DialogueTree.__index = DialogueTree

-- Built-in in-memory Blackboard with dot-path support (e.g. "flags.MetGuard")
function DialogueTree.blackboard(initial: { [string]: any }?): Blackboard
	local data: { [string]: any } = if initial then table.clone(initial) else {}
	local listeners: { [string]: { (payload: any?) -> () } } = {}

	local bb: any = {}

	function bb.get(_self: any, key: string): any
		if data[key] ~= nil then
			return data[key]
		end
		local cur: any = data
		for segment in string.gmatch(key, "[^%.]+") do
			if type(cur) ~= "table" then
				return nil
			end
			cur = cur[segment]
		end
		return cur
	end

	function bb.set(_self: any, key: string, value: any)
		if string.find(key, ".", 1, true) == nil then
			data[key] = value
			return
		end
		local parts: { string } = {}
		for segment in string.gmatch(key, "[^%.]+") do
			table.insert(parts, segment)
		end
		local cur: any = data
		for i = 1, #parts - 1 do
			local seg = parts[i]
			if type(cur[seg]) ~= "table" then
				cur[seg] = {}
			end
			cur = cur[seg]
		end
		cur[parts[#parts]] = value
	end

	function bb.has(self: any, key: string): boolean
		return self:get(key) ~= nil and self:get(key) ~= false
	end

	function bb.fire(_self: any, eventName: string, payload: any?)
		local list = listeners[eventName]
		if not list then
			return
		end
		for _, fn in table.clone(list) do
			fn(payload)
		end
	end

	function bb.onEvent(_self: any, eventName: string, fn: (payload: any?) -> ()): () -> ()
		local list = listeners[eventName]
		if not list then
			list = {}
			listeners[eventName] = list
		end
		table.insert(list, fn)
		return function()
			local idx = table.find(list, fn)
			if idx then
				table.remove(list, idx)
			end
		end
	end

	function bb.snapshot(_self: any): { [string]: any }
		return table.clone(data)
	end

	return bb :: Blackboard
end

-- Substitutes {key} placeholders from the blackboard
function DialogueTree.format(text: string, blackboard: Blackboard?): string
	if not blackboard then
		return text
	end
	local out = string.gsub(text, "{([%w_%.]+)}", function(key: string): string
		local val = blackboard:get(key)
		return if val ~= nil then tostring(val) else `{key}`
	end)
	return out
end

-- Static validator: catches missing entries, broken links, and duplicate choice ids
function DialogueTree.validate(tree: Tree): { string }
	local errors: { string } = {}
	if type(tree) ~= "table" then
		return { "tree must be a table" }
	end
	if type(tree.id) ~= "string" or #tree.id == 0 then
		table.insert(errors, "tree.id must be a non-empty string")
	end
	if type(tree.nodes) ~= "table" then
		table.insert(errors, "tree.nodes must be a table")
		return errors
	end

	local entries: { string } = if type(tree.entry) == "string"
		then { tree.entry }
		elseif type(tree.entry) == "table" then tree.entry :: { string }
		else {}
	if #entries == 0 then
		table.insert(errors, "tree.entry must name at least one start node")
	else
		for _, entryId in entries do
			if tree.nodes[entryId] == nil then
				table.insert(errors, `entry node "{entryId}" does not exist`)
			end
		end
	end

	for nodeId, node in tree.nodes do
		if type(node.text) ~= "string" or #node.text == 0 then
			table.insert(errors, `node "{nodeId}" has empty text`)
		end
		if node.next ~= nil and tree.nodes[node.next] == nil then
			table.insert(errors, `node "{nodeId}".next points to missing node "{node.next}"`)
		end
		if node.choices then
			local seen: { [string]: boolean } = {}
			for _, choice in node.choices do
				if type(choice.id) ~= "string" or #choice.id == 0 then
					table.insert(errors, `node "{nodeId}" has a choice with no id`)
				elseif seen[choice.id] then
					table.insert(errors, `node "{nodeId}" has duplicate choice id "{choice.id}"`)
				else
					seen[choice.id] = true
				end
				if choice.next ~= nil and tree.nodes[choice.next] == nil then
					table.insert(
						errors,
						`node "{nodeId}" choice "{choice.id}" points to missing node "{choice.next}"`
					)
				end
			end
		end
	end

	return errors
end

local function evalCondition(
	cond: Condition?,
	bb: Blackboard,
	named: { [string]: (Blackboard) -> boolean }?
): boolean
	if cond == nil then
		return true
	end
	if type(cond) == "function" then
		return cond(bb) == true
	end
	if type(cond) == "string" then
		if named and named[cond] then
			return named[cond](bb) == true
		end
		return bb:get(cond) == true
	end
	return false
end

local function runAction(action: Action?, bb: Blackboard, named: { [string]: (Blackboard) -> () }?)
	if action == nil then
		return
	end
	if type(action) == "function" then
		action(bb)
	elseif type(action) == "string" then
		if named and named[action] then
			named[action](bb)
		else
			local fire = bb.fire
			if fire then
				fire(bb, action)
			end
		end
	end
end

local function onceKey(treeId: string, nodeId: string, choiceId: string): string
	return `_dialogue_once.{treeId}.{nodeId}.{choiceId}`
end

function DialogueTree.new(tree: Tree, blackboard: Blackboard?, options: Options?): Runner
	local self: any = setmetatable({
		tree = tree,
		blackboard = blackboard or DialogueTree.blackboard(),
		changed = Signal.new(),
		ended = Signal.new(),
		_conditions = if options then options.conditions else nil,
		_actions = if options then options.actions else nil,
		_nodeId = nil :: string?,
		_snapshot = nil :: Snapshot?,
	}, DialogueTree)
	return self :: Runner
end

local function buildSnapshot(self: any, nodeId: string): Snapshot?
	local tree: Tree = self.tree
	local node = tree.nodes[nodeId]
	if not node then
		return nil
	end
	local bb: Blackboard = self.blackboard
	local choices: { SnapshotChoice } = {}
	if node.choices then
		for _, choice in node.choices do
			if choice.once and bb:get(onceKey(tree.id, nodeId, choice.id)) == true then
				continue
			end
			local passed = evalCondition(choice.when, bb, self._conditions)
			if not passed then
				if choice.locked == "disable" then
					table.insert(choices, {
						id = choice.id,
						label = DialogueTree.format(choice.label, bb),
						variant = choice.variant or "secondary",
						disabled = true,
						lockedReason = if choice.lockedReason
							then DialogueTree.format(choice.lockedReason, bb)
							else nil,
					})
				end
			else
				table.insert(choices, {
					id = choice.id,
					label = DialogueTree.format(choice.label, bb),
					variant = choice.variant or "secondary",
					disabled = false,
					lockedReason = nil,
				})
			end
		end
	end
	local hasChoices = #choices > 0
	local isEnd = node.isEnd == true or (not hasChoices and node.next == nil)
	return {
		treeId = tree.id,
		nodeId = nodeId,
		speaker = node.speaker or tree.speaker or "",
		text = DialogueTree.format(node.text, bb),
		audio = node.audio,
		animation = node.animation,
		mood = node.mood,
		meta = node.meta,
		canLeave = if tree.canLeave ~= nil then tree.canLeave else true,
		canAdvance = not hasChoices and (node.next ~= nil or isEnd),
		isEnd = isEnd,
		choices = choices,
	}
end

local function enterNode(self: any, nodeId: string): Snapshot?
	local tree: Tree = self.tree
	local prevId: string? = self._nodeId
	if prevId then
		local prevNode = tree.nodes[prevId]
		if prevNode then
			runAction(prevNode.onExit, self.blackboard, self._actions)
		end
	end
	local node = tree.nodes[nodeId]
	if not node then
		self._nodeId = nil
		self._snapshot = nil
		self.ended:Fire()
		return nil
	end
	self._nodeId = nodeId
	runAction(node.onEnter, self.blackboard, self._actions)
	local snap = buildSnapshot(self, nodeId)
	self._snapshot = snap
	self.changed:Fire(snap)
	return snap
end

function DialogueTree.start(self: any): Snapshot?
	local tree: Tree = self.tree
	local entries: { string } = if type(tree.entry) == "string"
		then { tree.entry }
		else tree.entry :: { string }
	local picked: string? = nil
	for _, entryId in entries do
		local candidate = tree.nodes[entryId]
		if candidate and evalCondition(candidate.when, self.blackboard, self._conditions) then
			picked = entryId
			break
		end
	end
	if not picked then
		self:close()
		return nil
	end
	return enterNode(self, picked)
end

function DialogueTree.choose(self: any, choiceId: string): (boolean, Snapshot?)
	local nodeId: string? = self._nodeId
	if not nodeId then
		return false, nil
	end
	local tree: Tree = self.tree
	local node = tree.nodes[nodeId]
	if not node or not node.choices then
		return false, nil
	end
	local chosen: Choice? = nil
	for _, c in node.choices do
		if c.id == choiceId then
			chosen = c
			break
		end
	end
	if not chosen then
		return false, nil
	end
	if chosen.once and self.blackboard:get(onceKey(tree.id, nodeId, chosen.id)) == true then
		return false, nil
	end
	if not evalCondition(chosen.when, self.blackboard, self._conditions) then
		return false, nil
	end
	if chosen.once then
		self.blackboard:set(onceKey(tree.id, nodeId, chosen.id), true)
	end
	runAction(chosen.onSelect, self.blackboard, self._actions)
	if chosen.close or not chosen.next then
		self:close()
		return true, nil
	end
	return true, enterNode(self, chosen.next)
end

function DialogueTree.advance(self: any): (boolean, Snapshot?)
	local nodeId: string? = self._nodeId
	if not nodeId then
		return false, nil
	end
	local node = self.tree.nodes[nodeId]
	if not node then
		self:close()
		return false, nil
	end
	if node.next and not node.isEnd then
		return true, enterNode(self, node.next)
	end
	self:close()
	return true, nil
end

function DialogueTree.close(self: any)
	local prevId: string? = self._nodeId
	if not prevId then
		return
	end
	local prevNode = self.tree.nodes[prevId]
	self._nodeId = nil
	self._snapshot = nil
	if prevNode then
		runAction(prevNode.onExit, self.blackboard, self._actions)
	end
	self.changed:Fire(nil)
	self.ended:Fire()
end

function DialogueTree.snapshot(self: any): Snapshot?
	return self._snapshot
end

function DialogueTree.nodeId(self: any): string?
	return self._nodeId
end

function DialogueTree.active(self: any): boolean
	return self._nodeId ~= nil
end

return DialogueTree
