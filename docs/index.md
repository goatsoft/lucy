---
title: Getting started
description: Install Lucy, create an App and build your first scene.
order: 1
---

# Getting started

Lucy is a UI and app framework for Roblox, built on
[Universal Styling](https://create.roblox.com/docs/ui/styling). It gives you
themeable components, scenes and one app state, and works with mouse, keyboard,
gamepad and touch on desktop, console, tablet and phone.

## Install

### Copy in (recommended)

Components are copied into your project as source you own. You need
[Lune](https://lune-org.github.io/docs) and a checkout of Lucy.

```sh
git clone https://github.com/goatsoft/lucy ~/Projects/Lucy
cd your-game
lune run ~/Projects/Lucy/scripts/add -- button dialog --from ~/Projects/Lucy --out src/shared/Lucy
```

- Core is always copied; dependencies come along (Dialog brings Button).
- Files you have edited are kept unless you pass `--overwrite`.
- `--list` shows every component, `--all` installs them all, `--specs` copies the tests too.

### Wally

```toml [wally.toml]
[dependencies]
Lucy = "goatsoft/lucy@0.1.0"
```

## Create the App

Create one App on the client. It owns the state, theme, input, scenes and toasts.

```luau [StarterPlayerScripts/UI.client.luau]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Shared.Lucy) -- or ReplicatedStorage.Packages.Lucy

local app = Lucy.App.new({
	theme = "dark",
	baseColor = "zinc",
	primary = "violet",
	state = { coins = 0 },
})
```

## Build a scene

Each scene owns one ScreenGui. Only one screen shows at a time; modals and
overlays sit above it. This one shows the player's coins and a button that adds
to them.

```luau
-- coins() reads the value, coins(10) writes it.
local coins = app.state:ref("coins")

app.scenes:register("Hud", {
	build = function(scene)
		Lucy.Stack.new({
			direction = "horizontal",
			align = "center",
			gap = "Space4",
			padding = "Space6",
			children = {
				Lucy.Text.new({
					-- A function is followed: the label updates when coins changes.
					text = function()
						return `Coins: {coins()}`
					end,
					variant = "h3",
					autoWidth = true,
				}),
				Lucy.Button.new({
					id = "collect", -- its state lives at ui.collect
					text = "Collect 10",
					onClick = function()
						coins(coins() + 10)
					end,
				}),
			},
			Parent = scene.gui,
		})
	end,
})

app.scenes:goTo("Hud")

-- Change state from anywhere in your game and the UI follows.
app.state:set("coins", 100)
```

On a screen the player moves around with keys or a gamepad, give the scene a
`defaultFocus` that returns what to select first. See
[Architecture](architecture.md#input-and-focus).

## Drive anything from app state

```luau
app.state:set("ui.collect.disabled", true)    -- any component, by id
app.state:set("theme", "light")               -- switch theme
app.state:set("scenes.current", "Game")       -- navigate
app.state:subscribe("input.device", print)    -- "desktop" | "console" | "tablet" | "mobile"
```

## Dialogs and toasts

```luau
local quit = Lucy.Dialog.new({
	id = "quit",
	title = "Leave match?",
	description = "You will drop your cash.",
	actions = {
		{ text = "Stay", variant = "outline" },
		{ text = "Leave", variant = "destructive", onClick = leaveMatch },
	},
})
quit:open() -- or app.state:set("ui.quit.open", true)

app.toast.success("Round won", { description = "+$250" })
```

## Next

- [Components](components/index.md): a page for each component with its props and examples
- [Stories and preview](stories.md): see your UI in Studio without pressing Play
- [Architecture](architecture.md): how the pieces fit together
- [Use Lucy with agents](guide/agents.md): give your coding agent Lucy's skills
- [Benchmarks](benchmarks.md): what mounting and updating UI costs
