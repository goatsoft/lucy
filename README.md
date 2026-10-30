<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/dist/logo-lockup.png">
    <img src="assets/brand/dist/logo-lockup-ink.png" alt="Lucy" height="128">
  </picture>
</p>

# Lucy

A UI kit and app framework for Roblox, built on
[Universal Styling](https://create.roblox.com/docs/ui/styling).

- **Only what changed updates**: change a value and only the properties that read it are set again. Nothing is rebuilt and nothing is diffed, so long lists and busy HUDs stay cheap ([benchmarks](docs/benchmarks.md)).
- **State in plain Luau**: a ref is a function you call (`count()`, `count(5)`), `computed` caches a derived value, `reactive` tables let you write fields, and `watch` runs code when something changes. You never list dependencies.
- **Cleanup is automatic**: effects, bindings and instances belong to whatever created them and are removed with it.
- **UI in code or in Studio**: describe UI with `Lucy.new`, `show` and `each`, or `hydrate` a ScreenGui built in Studio and add the behaviour.
- **Animation is state**: springs and tweens bind like any other value. Colours blend through Oklab, and nothing runs once every animation has stopped.
- **Components you own**: buttons, dialogs, toasts, inputs, panels and more. Copy them into your game with one command, or install the Wally package.
- **Styling runs in the engine**: themes are Universal Styling sheets, light and dark for each base colour, with an optional primary colour, switchable at runtime. Hover and theme changes run no Luau. Colours are defined in OKLCH.
- **Every input, every screen**: mouse, keyboard, gamepad and touch on desktop, console, tablet and phone, with densities, scaling and responsive props built in.
- **A focus ring you can see**: Lucy hides the Roblox selection ring and default borders and draws a themed ring, shown only while navigating with keys or a gamepad.
- **Preview in Studio**: write a story for any component or scene and see it in edit mode without pressing Play. Story controls are refs, so they bind to components both ways, and every story also runs as a test.
- **One app, separate scenes**: one store drives every component, scene and toast. The title screen, game, menus and modals each get their own layer and never take each other's input.
- **Small and tested**: one package with no runtime dependencies, strict types throughout, and hundreds of specs run in Studio.

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
- Set `LUCY_HOME=~/Projects/Lucy` to skip `--from`.

### Wally

```toml
[dependencies]
Lucy = "goatsoft/lucy@0.1.0"
```

## Usage

Create one App on the client, then build scenes from components.

```lua
-- StarterPlayerScripts/UI.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lucy = require(ReplicatedStorage.Shared.Lucy) -- or ReplicatedStorage.Packages.Lucy

local app = Lucy.App.new({ theme = "dark", baseColor = "zinc", primary = "violet" })

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

app.scenes:register("Game", {
	build = function(scene) --[[ HUD ]] end,
	onBack = function()
		app.scenes:goTo("Title") -- Escape or ButtonB
	end,
})

app.scenes:goTo("Title")
```

### Reactive UI

```lua
local coins = app.state:ref("player.coins")
local open = Lucy.ref(false)
local x = Lucy.spring(function() return if open() then 0 else -320 end)

Lucy.new "TextButton" {
	Text = function() return `Coins: {coins()}` end,
	Position = function() return UDim2.fromOffset(x(), 16) end,
	[Lucy.on "Activated"] = function() open(not open()) end,
	Parent = scene.gui,
}
```

Only the properties that read a changed ref update. See
[docs/reactivity.md](docs/reactivity.md).

### Drive anything from app state

```lua
app.state:set("ui.play.disabled", true)       -- any component, by id
app.state:set("theme", "light")               -- switch theme
app.state:set("scenes.current", "Game")       -- navigate
app.state:subscribe("input.device", print)    -- "desktop" | "console" | "tablet" | "mobile"
```

### Dialogs and toasts

```lua
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
app.toast("Invite from JB", { action = { label = "Join", onClick = join } })
```

### Layout that adapts

```lua
Lucy.Panel.new({
	title = "Loadout",
	maxWidth = 480,
	Parent = scene.gui,
	children = {
		Lucy.Stack.new({
			direction = { mobile = "vertical", default = "horizontal" },
			gap = { console = "Space6", default = "Space2" },
			children = {
				Lucy.Button.new({ text = "Pistol", variant = "outline" }),
				Lucy.Button.new({ text = "Rifle", variant = "outline" }),
			},
		}),
	},
})
```

Every component has a story in [examples/stories](examples/stories), and
[examples/Showcase.client.luau](examples/Showcase.client.luau) is a story browser built with Lucy.
Preview one from the command bar with `Lucy.Preview.show("Button")`.

## Components

Button, Badge, Text, Panel, Dialog (and alert dialog), Toaster, Input, Checkbox,
Switch, Progress, Skeleton, Separator, Stack. Props and state keys are in
[docs/components.md](docs/components.md).

## Documentation

The docs are published at [lucy.goatsoft.io](https://lucy.goatsoft.io) and live in this repo:

| Doc | What it covers |
|---|---|
| [docs/reactivity.md](docs/reactivity.md) | ref, computed, reactive, watch, `Lucy.new`, springs and tweens |
| [docs/architecture.md](docs/architecture.md) | How App, AppState, Theme, scenes and input fit together |
| [docs/components.md](docs/components.md) | Every component's props, state keys and responsive values |
| [docs/stories.md](docs/stories.md) | Stories, controls and previewing UI in Studio |
| [docs/benchmarks.md](docs/benchmarks.md) | Mount, update and teardown costs, and how to run the benchmarks |
| [docs/development.md](docs/development.md) | Toolchain, the TDD loop, writing a component, releasing |
| [docs/adr/](docs/adr) | Architecture decisions and why they were made |

The website itself is in `apps/site`; it is never part of the package.

## Contributing

```sh
rokit install && wally install
rojo serve test.project.json   # port 38574; connect the Rojo plugin in Studio
```

Then run the tests from the Studio command bar:

```lua
require(game.ReplicatedStorage.LucyTests.Runner).run()
```

See [docs/development.md](docs/development.md) before adding a component.

## License

MIT · by GOATsoft
