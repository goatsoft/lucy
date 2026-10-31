---
title: Contributing
description: Toolchain, the TDD loop, writing a component, pull requests and how releases happen.
order: 1
---

# Developing Lucy

## Toolchain

Pinned in `rokit.toml`. Install once with `rokit install`, then `wally install`
for TestEZ (into `DevPackages/`, gitignored).

| Tool | Use |
|---|---|
| rojo | sync source into Studio, build places |
| wally | TestEZ dev dependency, publishing `goatsoft/lucy` |
| lune | `scripts/add.luau` CLI, `scripts/gen-palette.luau` |
| selene / stylua | lint and format |
| run-in-roblox | headless test runs in CI |
| luau-lsp | type checking (editor or `luau-lsp analyze`) |

## Daily loop

1. Serve the dev place (port 38574 is in the project file):
   ```
   rojo serve test.project.json
   ```
2. In Studio, open any place (or `rojo build test.project.json -o ~/tmp/LucyTests.rbxl`
   and open that) and connect the Rojo plugin.
3. Run the specs from the command bar:
   ```luau
   require(game.ReplicatedStorage.LucyTests.Runner).run()
   require(game.ReplicatedStorage.LucyTests.Runner).run({ pattern = "Button" })
   ```
   `run` returns `{ passed, failed, skipped, errors, ok }`.
4. Look at a component without pressing Play:
   ```luau
   require(game.ReplicatedStorage.Lucy).Preview.show("Button", { root = game.ReplicatedStorage.LucyExamples })
   ```
   Press Play for the story browser (`examples/Showcase.client.luau`, mapped into
   StarterPlayerScripts), where every control is clickable.
5. After a change that could affect speed, run the benchmarks and compare with
   [the published numbers](benchmarks.md):
   ```luau
   require(game.ReplicatedStorage.LucyTests.Bench.Run).run()
   ```

Keep build output and scratch files outside the repo (for example `~/tmp`).

## TDD

1. Add or extend `X.spec.luau` next to the module. Describe behaviour, not
   implementation.
2. Run it, watch it fail for the right reason.
3. Implement until green, then tidy.

Spec helpers (`src/Testing/Harness.luau`):

- `Harness.app(config)` → `app, cleanup`: an isolated App with a deterministic
  desktop input profile and no engine listeners. Always call `cleanup` in `afterEach`.
- `Harness.caps.desktop / mobile / tablet / console` for `app.input:setCaps(...)`.
- `Harness.mount(app)` → a linked test ScreenGui to parent components into.
- `Harness.flush()` → wait for Universal Styling to apply (a few frames).
- `Harness.styled(instance, prop)` → the resolved value (`GetStyled`).
- `Harness.colorEq(a, b)` → Color3 compare within 1/255.

Gotchas:

- Never assert styled values with plain property reads; they return the
  unstyled value.
- `GetPropertyChangedSignal` events are deferred; `task.wait()` before asserting on a
  value set through a signal (see Input.spec).
- Do not set styled properties from component code; it overrides the theme.

## Writing a component

1. `src/Components/Thing.spec.luau` first.
2. `src/Components/Thing.luau`:
   ```luau
   --!strict
   local Component = require(script.Parent.Parent.Core.Component)
   local Element = require(script.Parent.Parent.Core.Element)
   local Thing = {}
   local rules: { Component.Rule } = {
       { selector = ".ui-thing", priority = 0, properties = { BackgroundColor3 = "$Card" } },
   }
   Thing.rules = rules
   local spec: Component.Spec = { -- built once, shared by every Thing
       kind = "thing", rules = Thing.rules,
       defaults = { text = "", visible = true },  -- the keys that live in state
       render = function(h)
           return Element.new("TextLabel", {
               Text = h:ref("text"),
               Visible = h:ref("visible"),
               Tags = { "ui-thing" },
           })
       end,
   }
   function Thing.new(props: Component.Props?): Component.Handle
       return Component.mount(spec, props)
   end
   return Thing
   ```
   Annotate the rules list as `{ Component.Rule }` so rules with different
   properties pass the type checker together. Render is declarative: bind properties,
   derive with `computed`, and keep watchers for side effects (see
   [Writing a component](components/index.md#writing-a-component)).
3. Visual properties go in `rules` with `$Token` values; layout and behaviour in code.
4. Sizes that should grow on touch or console come from density tokens:
   `Lucy.useMetric(app, "ControlMd")` or `Lucy.useDensity(app)` in `render`.
5. Anything interactive: `Interactable`/`Selectable` follow `disabled`, a
   keyboard path exists (`handle:click()` or `handle:toggle()`), and it works
   inside focus scopes.
6. Add a story, `examples/stories/Thing.story.luau`, with controls for its state
   keys ([stories](stories.md)). `tests/Stories.spec.luau` mounts every story in
   each theme and device.
7. Add it to `src/init.luau` and give it a one line description in
   `registry.json` (the copy-in installer works out its files and dependencies
   from `src` itself), give it a page in `docs/components/` and add it to the
   list in `docs/components/index.md`.
8. Grep for the em dash character before committing: `grep -rn $'\xe2\x80\x94' .`
   must return nothing.

## Static checks

```
rojo sourcemap test.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau \
  --definitions=@testez=testez.d.luau src tests
selene src tests examples
stylua --check src tests scripts examples
lune run scripts/add -- --check
```

The last one installs every component with the copy-in installer into a
temporary folder and checks that every `require` finds its module, and that
every component has a description in `registry.json`.

Every source file starts with `--!strict` and `luau-lsp analyze` must report
nothing. Specs stay in the default nonstrict mode (`.luaurc`) since TestEZ's
globals are loosely typed. Classes declare their type next to the metatable
(`export type AppState = typeof(setmetatable({} :: {...}, AppState))`) and
write methods as `function AppState.get(self: AppState, ...)`.

## Regenerating the palette

```
lune run scripts/gen-palette <path-or-url>
```

## The website

The site in `apps/site` renders this `docs/` folder
at `/docs/...`, plus a landing page. It needs Node 24 and pnpm.

```sh
pnpm install
pnpm site:dev        # local dev server
pnpm site:build      # prerendered static site in apps/site/dist
pnpm site:typecheck
```

- A Markdown file added under `docs/` becomes a page. Frontmatter `title`,
  `description` and `order` set its sidebar entry, and `sidebarTitle` gives the
  sidebar a shorter label when the page title is too long or repeats its group.
  The sidebar groups are in `apps/site/src/lib/docs.ts`.
- Links between docs files work on GitHub and on the site.
- Pushes to `main` that touch the site or docs deploy it via
  `.github/workflows/pages.yml`. Deploying never publishes the package.
- If a build logs a hydration mismatch, `LUCY_DEBUG_HYDRATION=1 pnpm site:build`
  explains it in the browser console.

## Docs examples

Every example in the docs is part of one game, **Club Lucy**: a dance club
where players dance, play DJ sets in the Booth, earn coins, buy emotes, queue
tracks and hang out with their crew. Lucy is the resident DJ. Each example shows
a common game pattern (a HUD, a menu, a shop, settings, a leaderboard, a
confirm, a hotkey) in that setting, so the docs read as one game.

- Names are invented: never real songs, artists, brands or games. The cast:
  tracks "Neon Nights" (DJ Lucy, 124 BPM), "Bassline Bounce" (Pixel Pulse, 128),
  "Sunset Groove" (The Glowsticks, 118), "Midnight Drop" (DJ Lucy, 140);
  dances Moonwalk, Robot, Shuffle, Twirl, Wave, Groove; places the Lobby, the
  Dance Floor, the Booth, the Wardrobe, the Emote Shop; crew Nova, Beatrix,
  Kai, Juno, Remy.
- App state used by examples: `player` (`name`, `coins`, `level`, `hype`,
  `combo`), `settings` (`music`, `sfx`, `crowd`, `lights`, `danceSpeed`), `booth` (`bpm`,
  `crossfade`, `deck`).
- Icons come from the docs icon sheet, `assets/docs-icons/lucy-icons.json`. To
  use a new one, add it to `include` there and rebuild (see below).
- Back keys are B and Backspace, never Escape.

## Example pictures

Every example that draws something shows a picture of it, in the site's light
or dark theme. A page marks each one with a `<!-- preview -->` line right
above its `luau` block. The marker can take options:

- `<!-- preview -->`: the code runs with only `Lucy`, `app` and `parent` in
  scope, so it parents what it makes to `parent` and starts from the app state
  above.
- `<!-- preview solo -->`: the same, drawn on its own because it opens a
  dialog, a sheet, a toast or anything else that covers the screen.
- `<!-- preview screen -->`: a whole client script (a recipe, the homepage
  example), shown full screen. It runs in edit mode too: the renderer stands in
  for `Players.LocalPlayer` and for remotes, which answer nothing.

Any marker can add `then="..."`: Luau run after the example, with the same
names in scope, such as going to the scene or opening the menu the picture
should show (`<!-- preview solo then="app.scenes:goTo('Title')" -->`). Names an
example only borrows from earlier on its page (a `settings` panel to parent to,
a list of `tracks`) come from the Club Lucy cast when it is rendered.

The first marked example on `docs/components/button.md` is named
`components-button`, the second `components-button-2`, and so on. The homepage
example, `apps/site/src/content/quickstart.md`, is `home-quickstart`.

Pictures come from Studio, so a person or an agent with Studio makes them. The
renderer is `scripts/doc-pictures.luau`, which the LucyTests place syncs as
`ReplicatedStorage.LucyDocPictures`. Cropping needs `cwebp` and `dwebp`
(libwebp, `brew install webp`).

1. `node scripts/doc-previews.ts serve` serves the marked examples to Studio
   on `127.0.0.1:38991`, and writes the pictures Studio sends back. Leave it
   running.
2. In Studio's edit mode, with the LucyTests place open:

   ```luau
   local R = require(game.ReplicatedStorage.LucyDocPictures)
   R.start()
   R.run()
   R.stop()
   ```

   `start()` loads the examples, makes its own copy of Lucy and registers the
   docs icons. `run()` draws the examples a screenful at a time, in the dark
   theme then the light one, captures Studio's viewport and sends each
   example's part to the server, which writes `<name>-dark.webp` and
   `<name>-light.webp` to `apps/site/public/images/examples`. Light and dark
   get the same frame, cut to what either theme drew. `stop()` takes away
   everything the renderer made. HTTP is turned on only while it talks to the
   server.

   To redraw a few pictures, call
   `R.only({ "components-button", "components-avatar" })` before `run()`.
3. `node scripts/doc-previews.ts write` puts each picture pair under its
   marker. `--check` fails when a marked example has no pictures.

The pictures are as big as Studio captures them: twice the viewport on a
Retina screen. Make them all on the same kind of screen so they match.
`node scripts/doc-previews.ts crop <dark capture> <light capture>` does the
same cutting from two screenshots taken another way, with the box lines from
`R.next` and `R.again` on its input.

Examples run with stand-ins for names they only borrow from earlier on their
page, and for a client (`Players.LocalPlayer`, remotes that answer nothing), so
no server script runs while pictures are made.

Re-render a page's pictures when its example or the component's look changes.

The docs icon sheet is built like a game's:

```sh
cd assets/docs-icons
set -a; source ../../.env; set +a    # LUCY_ICONS_API_KEY, kept out of git
node ../../libs/icons/dist/cli.js build
```

It writes `examples/DocIcons.luau`, which Rojo syncs into LucyTests.

## Pull requests

Changes come in as pull requests to `main`:

1. Fork the repository and make a branch.
2. Work as above: a spec that fails first, then the code, then the static checks.
   CI runs the same checks on every pull request.
3. If you change lucy-icons, add a changeset with `pnpm changeset`.
4. Open the pull request saying what changed and why.

The maintainer reviews every pull request. It merges once it is approved and CI
passes.

## Releases

Only the maintainer releases. Merging a pull request never publishes anything,
and contributors never publish to Wally or npm.

- **Lucy** goes to Wally when the maintainer bumps `version` in `wally.toml`,
  notes the changes and publishes.
- **lucy-icons** goes to npm through changesets: merged changesets open a
  "Version Packages" pull request, and the maintainer merging it publishes.
