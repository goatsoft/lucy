<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/dist/logo-lockup.png">
    <img src="assets/brand/dist/logo-lockup-ink.png" alt="Lucy" height="128">
  </picture>
</p>

# Lucy

A UI kit and app framework for Roblox, built on
[Universal Styling](https://create.roblox.com/docs/ui/styling).

- **Fine-grained by design**: change a value and only the properties that read it update. Nothing re-renders and nothing is diffed, so long lists and busy HUDs stay cheap.
- **State that reads like Luau**: refs you call like functions (`count()`, `count(5)`), cached `computed` values, `reactive` tables you write as fields, and `watch`. No dependency lists, no boilerplate.
- **Cleans up after itself**: effects, bindings and instances belong to whatever created them and go away with it. No cleanup bookkeeping, no leaks.
- **Declarative, or built in Studio**: describe UI with `Lucy.new`, `show` and `each`, or `hydrate` a ScreenGui built in Studio and just add the behaviour.
- **Motion is a value**: springs and tweens bind like any other state. Colours glide through Oklab, and nothing runs while everything is at rest.
- **Components you own**: buttons, dialogs, toasts, inputs, panels and more. Copy them into your game with one command, or install the Wally package.
- **Styling runs in the engine**: themes are Universal Styling sheets, light and dark per base colour with an optional primary hue, switched at runtime. Hover and theme changes cost no Lua. Colours are defined in OKLCH.
- **Every input, every screen**: mouse, keyboard, gamepad and touch on desktop, console, tablet and phone, with densities, adaptive scaling and responsive props built in.
- **Lucy owns focus**: no Roblox selection rings or default borders; a themed focus ring only while navigating with keys or a gamepad.
- **Preview in Studio**: write a story for any component or scene and see it in edit mode, no Play needed. Controls are refs, so they bind to components both ways, and every story doubles as a smoke test.
- **One app, clean scenes**: one store drives every component, scene and toast. Title screen, game, menus and modals each own a layer and never steal input.
- **Light and dependable**: one package with no runtime dependencies, strict types throughout, and hundreds of specs run in Studio.

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
