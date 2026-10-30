---
title: Getting started
description: Install Lucy, create an App and build your first scene.
order: 1
---

# Getting started

Lucy is a UI kit and app framework for Roblox, built on
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

local app = Lucy.App.new({ theme = "dark", baseColor = "zinc", primary = "violet" })
```

## Build a scene

Each scene owns one ScreenGui. Only one screen shows at a time; modals and
overlays sit above it.

```luau
app.scenes:register("Title", {
	build = function(scene)
		scene.play = Lucy.Button.new({
			id = "play",
			text = "Play",
			size = "lg",
			Parent = scene.gui,
			onClick = function()
				app.scenes:goTo("Game")
			end,
		})
	end,
	defaultFocus = function(scene)
		return scene.play -- selected first on keyboard or gamepad
	end,
})

app.scenes:goTo("Title")
```

## Drive anything from app state

```luau
app.state:set("ui.play.disabled", true)       -- any component, by id
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

- [Components](components.md): every component's props and state keys
- [Stories and preview](stories.md): see your UI in Studio without pressing Play
- [Architecture](architecture.md): how the pieces fit together
- [Benchmarks](benchmarks.md): what mounting and updating UI costs
