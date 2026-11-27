---
title: Dialogue
description: A themed NPC conversation panel with an actor portrait, typewriter text, branching responses and locked choices, paired with Lucy.DialogueTree.
---

# Dialogue

A conversation panel for talking with NPCs. Pair it with [Lucy.DialogueTree](../reference/dialogue-tree.md)
(or snapshots sent from your server) to show the speaker's portrait, type lines out with
[useReveal](../reference/composables/use-reveal.md), and let players pick branching responses
with mouse, touch, keyboard or gamepad.

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-dialogue-light.webp" alt="Dialogue example" loading="lazy"><img class="example-dark" src="/images/examples/components-dialogue-dark.webp" alt="Dialogue example" loading="lazy"></figure>

```luau
local bb = Lucy.DialogueTree.blackboard({ name = "Alex", score = 40 })
local tree = {
	id = "club_nova",
	speaker = "dj_nova",
	entry = "hub",
	nodes = {
		hub = {
			text = "Hey {name}! Ready for tonight's set at Club Lucy?",
			choices = {
				{ id = "tips", label = "Any rhythm tips?", next = "tips", variant = "default" },
				{
					id = "vip_mix",
					label = "Spin the VIP mix",
					next = "vip",
					when = function(b)
						return (b:get("score") or 0) >= 100
					end,
					locked = "disable",
					lockedReason = "Score 100+",
				},
				{ id = "leave", label = "Catch you later", close = true },
			},
		},
		tips = { text = "Stay on the beat to keep your combo climbing.", next = "hub" },
		vip = { text = "Dropping the VIP mix now!", isEnd = true },
	},
}

local runner = Lucy.DialogueTree.new(tree, bb)
runner:start()

Lucy.Dialogue.new({
	app = app,
	runner = runner,
	instant = true,
	size = UDim2.fromOffset(620, 0),
	resolveActor = function()
		return { name = "DJ Nova", role = "Resident DJ", portrait = 1 }
	end,
	Parent = parent,
})
```

## Chat sequence preview

When the player clicks a response, `DialogueTree` advances to the next node and `Dialogue`
updates the speaker's line, portrait and available responses in place. Linear beats without
choices show a **Continue** link (or **Leave** on an end node):

<!-- preview -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-dialogue-2-light.webp" alt="Dialogue example" loading="lazy"><img class="example-dark" src="/images/examples/components-dialogue-2-dark.webp" alt="Dialogue example" loading="lazy"></figure>

```luau
Lucy.Stack.new({
	direction = "vertical",
	gap = "Space3",
	size = UDim2.fromOffset(620, 0),
	automaticSize = Enum.AutomaticSize.Y,
	children = {
		Lucy.Dialogue.new({
			app = app,
			speaker = "DJ Nova",
			role = "Resident DJ",
			portrait = 1,
			text = "Stay on the beat to keep your combo climbing. Ready to head back?",
			instant = true,
			canAdvance = true,
			size = UDim2.fromScale(1, 0),
		}),
		Lucy.Dialogue.new({
			app = app,
			speaker = "DJ Nova",
			role = "Resident DJ",
			portrait = 1,
			text = "Dropping the VIP mix now! See you on the dance floor.",
			variant = "overlay",
			instant = true,
			isEnd = true,
			size = UDim2.fromScale(1, 0),
		}),
	},
	Parent = parent,
})
```

## Actor portraits

Pass `resolveActor(speakerId)` returning `{ name, role?, portrait? }`. `portrait` accepts:

- **A Roblox `Model`** (such as a live R15 NPC rig): cloned into a `ViewportFrame` and framed at
  head and shoulders automatically.
- **A `number` (`UserId`)**: rendered with [Avatar](avatar.md).
- **An image asset `string`**: cropped cleanly inside the portrait frame.
- **`nil`**: falls back to a themed [Avatar](avatar.md) monogram built from the speaker's name.

## Typewriter text and cues

Lines type out using [useReveal](../reference/composables/use-reveal.md) at `rate` characters a
second (default `48`). Clicking or tapping the panel while a line is typing finishes it
immediately, and players with reduced motion enabled see the full line at once.

Pass `onCue(snapshot)` to trigger voice lines (`snapshot.audio`), NPC animations
(`snapshot.animation`), mood changes (`snapshot.mood`), or camera angles (`snapshot.meta`)
each time a new node is entered.

## Server-authoritative conversations

For games where dialogue grants cash, items or unlocks doors, run `Lucy.DialogueTree` on the
server against the player's saved profile flags (`Lucy.Profiles`) and replicate the current
`Snapshot` to `server.me.dialogue`. On the client, bind `Dialogue` directly to that ref:

```luau
Lucy.Dialogue.new({
	app = app,
	snapshot = app.state:ref("server.me.dialogue"),
	variant = "overlay",
	resolveActor = function(speakerId)
		return Actors.resolve(speakerId)
	end,
	onChoose = function(choiceId)
		app.server:send("dialogue.choose", choiceId)
	end,
	onAdvance = function()
		app.server:send("dialogue.advance")
	end,
	onClose = function()
		app.server:send("dialogue.close")
	end,
})
```

## Variants and theming

`Dialogue` ships with three built-in variants: `default`, `overlay` and `inverse`. Add your own
with `Lucy.Dialogue.addVariant(name, rules)` or override `.ui-dialogue-panel`,
`.ui-dialogue-portrait`, `.ui-dialogue-speaker` and `.ui-dialogue-text` in your game's theme.

## Props

| Prop | Type | Default | What it does |
|---|---|---|---|
| `runner` | DialogueRunner | | Connects directly to a local `Lucy.DialogueTree` runner |
| `snapshot` | Snapshot or Ref | | Reactive snapshot (e.g. `app.state:ref("server.me.dialogue")`) |
| `speaker` | string or Ref | `""` | Speaker name when driving `Dialogue` with direct props |
| `role` | string or Ref | | Optional role badge shown beside the speaker's name |
| `portrait` | Model, number or string | | Live rig, UserId, or image asset for the portrait |
| `text` | string or Ref | `""` | Current line of dialogue |
| `choices` | table or Ref | `{}` | List of `{ id, label, variant?, disabled?, lockedReason? }` |
| `variant` | string | `"default"` | `default`, `overlay`, `inverse` or a registered variant |
| `rate` | number | `48` | Characters per second for typewriter reveal |
| `instant` | boolean | `false` | Skip typewriter reveal and show text immediately |
| `resolveActor` | function | | `(speakerId) -> { name?, role?, portrait? }` |
| `onCue` | function | | `(snapshot)` called once each time a new node is entered |
| `onChoose` | function | | `(choiceId)` called when the player picks an unlocked choice |
| `onAdvance` | function | | Called when the player presses Continue on a linear node |
| `onClose` | function | | Called when the player leaves or finishes an end node |
| `continueText` | string | `"Continue"` | Button label on linear nodes without choices |
| `leaveText` | string | `"Leave"` | Button label on end nodes |
| `portraitSize` | number | `96` | Width and height of the portrait box in pixels |
| `maxWidth` | number | `760` | Maximum panel width when `size` is not given |
