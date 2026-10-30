# Lucy

A UI kit and app framework for Roblox, built on
[Universal Styling](https://create.roblox.com/docs/ui/styling).

- **Components you own**: copy them into your game with one command, or install the Wally package.
- **Themes as data**: light and dark themes per base colour, an optional primary hue, switchable at runtime. Colours are defined in OKLCH.
- **Every platform**: mouse, keyboard, gamepad and touch on desktop, console, tablet and phone, with densities, adaptive scaling and responsive props built in.
- **Lucy owns focus**: no Roblox selection rings or default borders; a themed focus ring only while navigating with keys or a gamepad.
- **App state**: one store drives every component, scene and toast.
- **Scenes**: title screen, game, menus and modals that never overlap or steal input.

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

A full runnable example is in [examples/Showcase.client.luau](examples/Showcase.client.luau).

## Components

Button, Badge, Text, Panel, Dialog (and alert dialog), Toaster, Input, Checkbox,
Switch, Progress, Skeleton, Separator, Stack. Props and state keys are in
[docs/components.md](docs/components.md).

## Documentation

| Doc | What it covers |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How App, AppState, Theme, scenes and input fit together |
| [docs/components.md](docs/components.md) | Every component's props, state keys and responsive values |
| [docs/development.md](docs/development.md) | Toolchain, the TDD loop, writing a component, releasing |
| [docs/adr/](docs/adr) | Architecture decisions and why they were made |

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
