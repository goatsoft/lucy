<!-- Made by scripts/skills.ts from docs/reference/dialogue-tree.md. Edit the doc, not this file. -->
# Dialogue trees

`Lucy.DialogueTree` is a pure Luau conversation engine that runs on both the server and the
client. Pair it with [Lucy.Dialogue](../components/dialogue.md) for the UI, or run it on the
server to keep quest flags, rewards and condition gates completely server-authoritative.

## Flat ModuleScript trees

Store each NPC's conversation in its own `ModuleScript` under `ReplicatedStorage` so both the
server and client can read it. Nodes live in a flat dictionary keyed by `nodeId` rather than
deeply nested tables, making loops and merges easy to read and maintain:

```luau
-- ReplicatedStorage/Shared/Dialogues/DjNova.luau
return {
	id = "dj_nova",
	speaker = "dj_nova",
	entry = { "greet_vip", "greet_default" }, -- Priority Stack
	nodes = {
		greet_vip = {
			when = function(bb)
				return bb:get("flags.Vip") == true
			end,
			text = "Welcome back, {name}. Booth is yours.",
			mood = "smirk",
			next = "hub",
		},
		greet_default = {
			text = "First night at Club Lucy, {name}?",
			audio = "Nova_Greet",
			onEnter = function(bb)
				bb:set("flags.MetNova", true)
			end,
			next = "hub",
		},
		hub = {
			text = "What can I do for you?",
			choices = {
				{ id = "tips", label = "Any tips?", next = "tips", once = true },
				{
					id = "secret",
					label = "Spin the VIP mix",
					next = "vip_done",
					when = function(bb)
						return (bb:get("score") or 0) >= 100
					end,
					locked = "disable",
					lockedReason = "Score 100+",
					onSelect = function(bb)
						bb:fire("playVipMix")
					end,
					variant = "default",
				},
				{ id = "leave", label = "See you later.", close = true },
			},
		},
		tips = { text = "Hit notes on the beat to keep your combo climbing.", next = "hub" },
		vip_done = { text = "Dropping the VIP mix now!", isEnd = true },
	},
}
```

## Structural patterns

| Pattern | How to write it in `DialogueTree` | Best for |
|---|---|---|
| **Branch and Bottleneck** | Split into flavour reactions with `choices`, then point each branch's `next` at the same pinch-point `nodeId`. | Story conversations that react to choices without exploding in size. |
| **Hub and Spokes** | Give a central `hub` node several questions; each spoke sets `next = "hub"` and optionally `once = true` on its choice. | Lore, investigations, shopkeepers and recruiting desks. |
| **Priority Stack / Router** | Set `entry = { "greet_quest_done", "greet_night", "greet_default" }` with `when(bb)` gates on each greeting node. | Dynamic NPCs reacting to quest progress, reputation or time of day. |

## Blackboard and persistent flags

Pass a `Blackboard` when creating a runner (`{ get, set, has?, fire? }`). For quick local
testing or client previews, `Lucy.DialogueTree.blackboard(initial?)` creates an in-memory
blackboard with dot-path support (`"flags.MetNova"`).

In a multiplayer game, save player memory (`flags = { MetNova = true, QuestStage = 2 }`) inside
the player's profile through [Lucy.Profiles](data-queue.md), and build a server-side blackboard
that reads/writes those profile flags and triggers verified server events on `bb:fire(name)`.

## Conditions, locked choices and actions

- **`when`**: a function `function(bb) -> boolean`, or a string checked against `options.conditions`
  (or `bb:get(key) == true`).
- **`locked`**: `"hide"` (default, omits the choice when `when` fails) or `"disable"` (keeps the
  choice visible and disabled, showing `lockedReason`).
- **`once = true`**: records the choice on the blackboard once picked so it is omitted on future
  visits to the same hub.
- **`onEnter` / `onExit` / `onSelect`**: a function `function(bb)` or a string event name fired
  through `options.actions` or `bb:fire(name)`.

## Static validation

Call `Lucy.DialogueTree.validate(tree)` in your game's test suite to catch typos before they
reach players:

```luau
local errors = Lucy.DialogueTree.validate(DjNova)
assert(#errors == 0, table.concat(errors, "\n"))
```

## API

| Member | Description |
|---|---|
| `DialogueTree.new(tree, blackboard?, options?)` | Creates a runner for `tree`. |
| `DialogueTree.blackboard(initial?)` | Creates an in-memory blackboard with dot-path `get`/`set`/`has`/`fire`/`onEvent`. |
| `DialogueTree.format(text, blackboard?)` | Replaces `{key}` tokens from the blackboard. |
| `DialogueTree.validate(tree)` | Returns a list of validation error strings (empty when valid). |
| `runner:start()` | Evaluates `tree.entry` (Priority Stack), runs `onEnter`, returns `Snapshot?`. |
| `runner:choose(choiceId)` | Verifies `when`, marks `once`, runs `onSelect`/`onExit`, advances and returns `(ok, Snapshot?)`. |
| `runner:advance()` | Follows `node.next` on linear beats or closes on end nodes, returning `(ok, Snapshot?)`. |
| `runner:close()` | Runs `onExit` and closes the conversation. |
| `runner.changed`, `runner.ended` | `Lucy.Signal` events fired on node change and conversation end. |
