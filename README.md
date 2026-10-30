# Lucy

A [shadcn](https://www.shadcn-vue.com/)-style UI kit and app framework for Roblox, built on
[Universal Styling](https://create.roblox.com/docs/ui/styling) with the
[Tailwind v4 palette](https://tailwindcss.com/docs/colors) in OKLCH.

- **Components you own**: copy them into your game with one command, or install the Wally package.
- **Themes as data**: light and dark per shadcn base colour (zinc, slate, stone ...), tinted primary, swap at runtime.
- **Every platform**: mouse, keyboard, gamepad and touch; desktop, console, tablet and phone. Densities, adaptive scaling and responsive props out of the box.
- **Lucy owns focus**: no Roblox selection rings or default borders; a themed focus ring only while navigating with keys or a pad.
- **App state**: one store drives every component, scene and toast.
- **Scenes**: title screen, game, menus and modals that never overlap or steal input.

```lua
local Lucy = require(ReplicatedStorage.Packages.Lucy)
local app = Lucy.App.new({ theme = "dark", baseColor = "zinc", primary = "violet" })

app.scenes:register("Title", {
    build = function(scene)
        scene.play = Lucy.Button.new({
            id = "play", text = "Play", size = "lg", Parent = scene.gui,
            onClick = function() app.scenes:goTo("Game") end,
        })
    end,
    defaultFocus = function(scene) return scene.play end,
})
app.scenes:goTo("Title")

app.state:set("ui.play.disabled", true)            -- control any component from anywhere
app.toast.success("Welcome back", { description = "Daily reward ready" })
```

## Install

**Copy in (shadcn style)** with [Lune](https://lune-org.github.io/docs):

```
LUCY_HOME=~/Projects/roblox-ui-kit lune run ~/Projects/roblox-ui-kit/scripts/add -- button dialog --out src/shared/Lucy
lune run ~/Projects/roblox-ui-kit/scripts/add -- --list --from ~/Projects/roblox-ui-kit
```

Core is always copied; dependencies come along (Dialog brings Button). Files you have
edited are kept unless you pass `--overwrite`.

**Wally**:

```toml
[dependencies]
Lucy = "goatsoft/lucy@0.1.0"
```

## Components

Button, Badge, Text, Panel (Card), Dialog and Alert Dialog, Toaster (Sonner), Input,
Checkbox, Switch, Progress, Skeleton, Separator, Stack. See [docs/components.md](docs/components.md).

## Docs

- [Architecture](docs/architecture.md): how App, AppState, Theme, scenes and input fit together
- [Development](docs/development.md): toolchain, TDD loop, writing a component
- [Components](docs/components.md): props, state keys, responsive values
- [Decisions](docs/adr): why things are the way they are

## Develop

```
rokit install && wally install
rojo serve test.project.json        # port 38574; connect the Rojo plugin in Studio
```

Then in the Studio command bar: `require(game.ReplicatedStorage.LucyTests.Runner).run()`.

## Credits

Lucy by GOATsoft. Design language from [shadcn/ui](https://ui.shadcn.com) and
[shadcn-vue](https://www.shadcn-vue.com); colours from [Tailwind CSS](https://tailwindcss.com);
Oklab by Björn Ottosson; tests with [TestEZ](https://roblox.github.io/testez/).
Co-authored with Claude.

## License

MIT
