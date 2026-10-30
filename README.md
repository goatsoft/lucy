<p align="center">
  <a href="https://lucy.goatsoft.io">
    <img src="https://raw.githubusercontent.com/goatsoft/lucy/main/assets/brand/readme/lucy-head.webp" alt="Lucy" height="200">
  </a>
</p>

<h1 align="center">Lucy</h1>

<p align="center">
  <a href="https://lucy.goatsoft.io/docs/">Getting started</a> ·
  <a href="https://lucy.goatsoft.io/docs/components/">Components</a> ·
  <a href="https://lucy.goatsoft.io/docs/reactivity/">Reactivity</a> ·
  <a href="https://lucy.goatsoft.io/docs/architecture/">Architecture</a> ·
  <a href="https://lucy.goatsoft.io/docs/guide/agents/">Agents</a> ·
  <a href="https://lucy.goatsoft.io/docs/benchmarks/">Benchmarks</a>
</p>

<p align="center">A UI and app framework for Roblox, built on Universal Styling.</p>

<p align="center">
  <a href="https://github.com/goatsoft/lucy/actions/workflows/ci.yml"><img src="https://github.com/goatsoft/lucy/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://lucy.goatsoft.io"><img src="https://img.shields.io/badge/docs-lucy.goatsoft.io-8757e2" alt="Docs"></a>
  <a href="https://wally.run/package/goatsoft/lucy"><img src="https://img.shields.io/badge/wally-goatsoft%2Flucy-c050ea" alt="Wally"></a>
  <a href="https://github.com/goatsoft/lucy/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-5bd0f8" alt="MIT License"></a>
</p>

## Overview

One source of truth for your UI and app state. Lucy tracks changes and updates
the UI for you. Themed components that work with mouse, keyboard, gamepad and
touch.

The components (buttons, dialogs, toasts, inputs, switches, panels and more)
come with light and dark themes and work on desktop, console, tablet and phone.
Their looks are Universal Styling rules, so hovering and switching themes run
no Luau.

When a value changes, only the properties that read it are set again. Nothing is
rebuilt and nothing is diffed, so long lists and busy HUDs stay cheap.

## Installation

### Wally

```toml
[dependencies]
Lucy = "goatsoft/lucy@0.1.0"
```

### Copy the source

If you would rather own and edit the components, copy them into your project
with [Lune](https://lune-org.github.io/docs) and a checkout of Lucy:

```sh
git clone https://github.com/goatsoft/lucy ~/Projects/Lucy
cd your-game
lune run ~/Projects/Lucy/scripts/add -- button dialog --from ~/Projects/Lucy --out src/shared/Lucy
```

The core comes along, and so do dependencies (Dialog brings Button). Files you
have changed are kept unless you pass `--overwrite`. Use `--list` to see every
component and `--all` to copy them all.

## Usage

Create one App on the client, then build scenes from components. This one is a
settings menu: a volume slider the game reads, and a theme picker that switches
the whole UI.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lucy = require(ReplicatedStorage.Packages.Lucy)

-- One app per player. Its state holds your game's data, and the theme.
local app = Lucy.App.new({
	theme = "dark",
	state = { settings = { volume = 50 } },
})

app.scenes:register("Settings", {
	build = function(scene)
		Lucy.Stack.new({
			size = UDim2.fromScale(1, 1),
			align = "center",
			justify = "center",
			children = {
				Lucy.Panel.new({
					title = "Settings",
					maxWidth = 400,
					children = {
						-- Each control is bound to a value in state, both ways.
						Lucy.Text.new({ text = "Volume", variant = "label" }),
						Lucy.Slider.new({ value = app.state:ref("settings.volume"), showValue = true }),
						Lucy.Text.new({ text = "Theme", variant = "label" }),
						Lucy.Select.new({
							items = { { value = "dark", label = "Dark" }, { value = "light", label = "Light" } },
							value = app.state:ref("theme"), -- pick Light and the whole UI switches
						}),
					},
				}),
			},
			Parent = scene.gui,
		})
	end,
})

app.scenes:goTo("Settings")

-- The game reads the same state. No glue code in between.
app.state:subscribe("settings.volume", function(volume)
	SoundService.Music.Volume = volume / 100
end)
```

Any property of any instance can follow a value. Here a button shows the coins
and slides on a spring:

```lua
local coins = app.state:ref("coins")
local open = Lucy.ref(false)
local x = Lucy.spring(function() return if open() then 0 else -320 end)

Lucy.new "TextButton" {
	Text = function() return `Coins: {coins()}` end,
	Position = function() return UDim2.fromOffset(x(), 16) end,
	[Lucy.on "Activated"] = function() open(not open()) end,
	Parent = gui,
}
```

Every component keeps its state in the app's store, so game code can change any
of it by id:

```lua
app.state:set("ui.quit.open", true)         -- open the quit dialog
app.state:set("theme", "light")             -- switch theme
app.state:set("scenes.current", "Game")     -- change screen

app.toast.success("Round won", { description = "+$250" })
```

## Features

- Button, Pressable, Badge, Text, Panel, Dialog, Toaster, Input, Checkbox,
  Switch, Toggle, Toggle Group, Tabs, Radio Group, Progress, Skeleton,
  Separator, Stack, Scroll Area, Grid, Item, Spinner, Alert, Image, Avatar,
  Icon, Kbd, Sheet, Select, Table, DataGrid, Slider, Number Field, Collapsible
  and Accordion.
- Light and dark themes for each base colour, with an optional primary colour,
  switchable while the game runs.
- Controls that grow for touch and console, and layout props that change with
  the device.
- A themed focus ring in place of the Roblox selection ring, shown only while
  navigating with keys or a gamepad.
- Scenes on separate layers, so menus and modals never take input from the
  screen below.
- Refs, computed values, springs and tweens that bind to any property.
- Named hotkeys for keyboard and gamepad, switched off together while a menu is
  open, and a way to stop the character moving under a dialog.
- Any Iconify icon by name, packed into a few uploaded images by the
  lucy-icons build.
- `Lucy.hydrate` to add behaviour to UI built in Studio.
- Stories that preview any component or scene in Studio without pressing Play.
- Skills for Claude Code, Codex and Antigravity, so coding agents build with
  Lucy's components and rules.
- Strict types, no runtime dependencies, and over 750 specs.

## Architecture

```
App                one per client
├─ AppState        every piece of UI state, in one tree of tables
├─ Theme           Universal Styling sheets and the rules for every component
├─ InputManager    input mode, device, focus and the back button
├─ SceneManager    one ScreenGui per scene, on layers
└─ toast           the toast API
```

Components keep their state in AppState at `ui.<id>`. Each one builds its
instances once and binds their properties to that state, so a write to one key
updates only the properties that read it. Code sets behaviour and layout; looks
come from style rules matched by tags.

The [architecture guide](https://lucy.goatsoft.io/docs/architecture/) covers
the rest.

---

<p align="center">
  <a href="https://goatsoft.io">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/goatsoft/lucy/main/assets/brand/goatsoft/GOATsoft-masthead-light.png">
      <img src="https://raw.githubusercontent.com/goatsoft/lucy/main/assets/brand/goatsoft/GOATsoft-masthead.png" alt="GOATsoft" height="48">
    </picture>
  </a>
  <br>
  Made by <a href="https://goatsoft.io">GOATsoft</a> · <a href="https://github.com/goatsoft/lucy/blob/main/LICENSE">MIT License</a>
</p>
