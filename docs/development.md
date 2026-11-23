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
| luau-lsp | type checking (editor or `sh scripts/types.sh`) |

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
   `run` returns `{ passed, failed, skipped, errors, ok }`. Each run tests fresh
   copies of `Lucy`, `LucyTests` and `LucyExamples`, because Studio keeps the first
   loaded copy of a module: without them an edit-mode run after a Rojo sync would
   test the old code. `{ fresh = false }` runs the originals. The Runner itself is
   still the first loaded copy, so after changing `tests/Runner.luau` restart Play
   or Studio.
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
  desktop input profile, no engine listeners and no UIScale (pass `adaptive = {}` for
  one; on a client it would follow the Studio window). Always call `cleanup` in `afterEach`.
- `Harness.caps.desktop / mobile / tablet / console` for `app.input:setCaps(...)`.
- `Harness.mount(app)` → a linked test ScreenGui to parent components into.
- `Harness.flush()` → wait for Universal Styling to apply (a few frames).
- `Harness.styled(instance, prop)` → the resolved value (`GetStyled`).
- `Harness.colorEq(a, b)` → Color3 compare within 1/255.
- `Harness.waitFor(check, timeout?)` → waits until `check()` is true (up to a second by
  default) and says whether it got there. Use it for what follows a delay or a layout pass,
  not a fixed `task.wait`, which fails whenever a frame runs long.

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
   `registry.json` (the copy in installer works out its files and dependencies
   from `src` itself), give it a page in `docs/components/` and add it to the
   list in `docs/components/index.md`.
8. Grep for the em dash character before committing: `grep -rn $'\xe2\x80\x94' .`
   must return nothing.

## Static checks

```
sh scripts/types.sh
selene src tests examples
stylua --check src tests scripts examples
lune run scripts/add -- --check
```

The last one installs every component with the copy in installer into a
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
- Write for a person making a game, in plain English with Australian spelling (colour,
  behaviour, centre). Say what the example shows and when you would use it. No buzzwords,
  no hyphenated words unless the word needs one, no em-dash.

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
  for `Players.LocalPlayer` and for remotes, which answer nothing. An App made
  with `server = true` gets a mock server: `app.server:call` answers from
  `S.ANSWERS` in `scripts/doc-pictures.luau` (`boards.get` gives the crew's
  rows), and anything else gets `nil`.
- `<!-- preview screen trim -->`: the same, but the picture is cut to what the
  script drew, as for other examples, and the frame fits the picture. Use it
  when the script draws one panel in the middle of the screen, as the homepage
  example does.
- `<!-- preview world -->`: a whole client script that draws in the world
  (an aura, a part), shown full screen at night with no backdrop so the 3D
  view shows and a glow reads.
  The script places the camera; afterwards the renderer puts the camera back
  and removes what the script made in `workspace`.
- `<!-- preview animate="1.6" fps="12" warmup="0.4" -->`: advances
  `Animate.manual` step by step and writes a looping animated WebP pair with
  `img2webp`. Use `warmup` to skip an opening delay and start mid motion.

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
`ReplicatedStorage.LucyDocPictures`. Cropping and animation need `cwebp`,
`dwebp` and `img2webp` (libwebp, `brew install webp`).

1. Open the LucyTests place in Studio, in edit mode, with Studio as an MCP
   server (**Assistant**, **...**, **Manage MCP Servers**, **Enable Studio as
   MCP server**), the same setting the Lucy MCP needs.
2. `node scripts/doc-previews.ts render` draws every marked example, or
   `render components-button components-avatar` just those. It works through
   Studio's MCP server with the Lucy MCP's Studio client, so Studio makes no
   HTTP requests and the place needs no saving or permissions. A screenful at a
   time, it draws the examples in the dark theme, captures Studio's viewport,
   draws them again in the light theme at the same places, captures again, and
   writes `<name>-dark.webp` and `<name>-light.webp` to
   `apps/site/public/images/examples`. Light and dark get the same frame, cut to
   what either theme drew. When it is done, everything the renderer made is
   taken away.
3. `node scripts/doc-previews.ts write` puts each picture pair under its
   marker. `--check` fails when a marked example has no pictures.

The pictures are as big as Studio captures them. Make them all on the same
kind of screen so they match.
`node scripts/doc-previews.ts crop <dark capture> <light capture>` does the
same cutting from two screenshots taken another way, with the box lines from
the renderer's `next` and `again` on its input.

Examples run with mock data for names they only borrow from earlier on their
page, and for a client (`Players.LocalPlayer`, remotes that answer nothing), so
no server script runs while pictures are made.

Render a page's pictures again when its example or the component's look changes.

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
3. If you change lucy-icons or lucy-mcp, add a changeset with `pnpm changeset`.
4. Open the pull request saying what changed and why.

The maintainer reviews every pull request. It merges once it is approved and CI
passes.

## Releases

Only the maintainer releases. Merging a pull request never publishes anything,
and contributors never publish to Wally or npm.

### Lucy, on Wally

The Luau package is `goatsoft/lucy`. Its version is `version` in `wally.toml`,
and `CHANGELOG.md` at the top of the repo says what each version changed.

1. Bump `version` in `wally.toml`. Update the version in the README's install
   line and in `plugins/lucy/.claude-plugin/plugin.json` to match.
2. Add the version to `CHANGELOG.md`: what is new, what was fixed, and what a
   game has to change (anything breaking goes first).
3. Run every check on that commit: the [static checks](#static-checks), the
   whole test suite in Studio with 0 failed (CI cannot run it), the em-dash
   check and `pnpm site:build`.
4. Check what will ship: `wally package --list` shows only `src/` (no specs, no
   `src/Testing`), `wally.toml`, `default.project.json`, `README.md` and
   `LICENSE`.
5. Commit (`chore(release): 0.1.0`), push, and wait for Release and Pages to go
   green: `gh run list --limit 3`.
6. Tag it and push the tag: `git tag v0.1.0 && git push origin v0.1.0`.
7. Publish: `wally login` (once per machine, with a GitHub account in the
   goatsoft organisation), then `wally publish`. A version can never be
   published twice or taken back, so this comes last.
8. Check it: the version shows on
   [wally.run](https://wally.run/package/goatsoft/lucy). In an empty folder,
   a `wally.toml` with `Lucy = "goatsoft/lucy@0.1.0"` installs with
   `wally install`, and the README's usage example runs in Studio.
9. Make the GitHub Release from the tag with that version's `CHANGELOG.md`
   entry: `gh release create v0.1.0 --title "Lucy 0.1.0" --notes-file <notes>`.

Before 1.0, a minor version (0.2.0) may break things and a patch (0.1.1) never
does. Games pin `goatsoft/lucy@0.1.0`, which takes patches only.

### lucy-icons and lucy-mcp, on npm

Both go to npm through changesets. Describe the change with `pnpm changeset`;
merged changesets open a "Version Packages" pull request, and the maintainer
merging it publishes, tags the version and makes its GitHub Release. Publishing
uses npm trusted publishing from the Release workflow, so there is no token.

npm only takes a trusted publisher for a package that already exists, so a new
package goes up by hand once before its first release:

1. Publish an empty placeholder from a folder outside the repo, with only a
   `package.json` holding the package's name, version `0.0.0` and the licence:
   `npm login`, then `npm publish --access public`.
2. On npmjs.com, in the package's settings under Trusted publishing, add a
   GitHub Actions publisher: organisation `goatsoft`, repository `lucy`,
   workflow `release.yml`, environment `npm`.
3. Merge the "Version Packages" pull request as usual. If its Release run
   already failed with `ENEEDAUTH`, re-run the failed job:
   `gh run rerun <run id> --failed`.
4. Mark the placeholder as old:
   `npm deprecate <name>@0.0.0 "Placeholder, use 0.1.0 or later"`.
