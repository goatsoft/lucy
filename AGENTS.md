# AGENTS.md

Start with [README.md](README.md); it links to the architecture, component and
development docs. Read the relevant ADRs in `docs/adr/` before changing structure,
and add a new ADR for any structural decision.

Rules:

- Never use the em-dash character anywhere (code, comments, docs, commits).
  Check: `grep -rnI $'\xe2\x80\x94' --exclude-dir=.git --exclude-dir=DevPackages .` prints nothing.
- TDD: write the `*.spec.luau` first, see it fail, then implement.
- Looks belong in style rules with `$Token` values; code sets behaviour and layout only.
- Components keep state in AppState at `ui.<id>` and work with mouse, keyboard, gamepad and touch.
- Components are declarative (ADR 0018): `render` binds instances to `h:ref(key)`, refs and
  getters. Derive with `computed` (writable when two-way), or a plain function when the
  work is trivial; share logic with composables (`Lucy.use*`, `src/Composables`).
  `Lucy.watch` / `watchEffect` are for side effects only (tweens, callbacks into user code,
  focus scopes, back handlers, sounds), never to set a property, tag or attribute a
  binding could own. Review enforces this.
- Code and docs do not name third-party design systems or CSS frameworks; ADRs may.
- ADRs are repo only: never mention or link them in `docs/` pages, the README or the website.
- Scratch files go outside the repo (e.g. `/tmp`).
- Images in the repo are SVG or WebP only: no PNG, JPEG or GIF. Docs example pictures
  are WebP (`scripts/doc-previews.ts`, docs/development.md "Example pictures"). The only
  PNGs are those a platform requires: the site's favicons, app icons and `og.png`, icon
  sheets uploaded to Roblox, and the Studio plugin icon.
- Only the Luau package ships. The website (`apps/site`, `libs/`) is never part of it;
  a new top-level path must be added to `wally.toml`'s `exclude` (CI checks).
- `libs/gruff` is the docs engine the site uses, and this copy is the source. It will move out into its own package, `@goatsoft/gruff`, which Aurora will then use; until then, change it here only and never edit Aurora's older copy.
- Tests run in the Lucy dev place Studio window only, never a game's:
  `require(game.ReplicatedStorage.LucyTests.Runner).run()`. JB serves Rojo himself (port 38574).
- Shell commands on JB's Mac run through zsh: `zsh -lc "cd ~/Projects/Lucy && ..."`.
- Format before committing: `stylua src tests scripts examples` (CI runs `stylua --check`).
- Commit messages are semantic: `type(scope): summary`, lower case, no full stop,
  in the imperative ("fix(select): close on back"). Types: `feat` (something new
  for games), `fix` (a bug), `docs`, `refactor`, `perf`, `test`, `build`, `ci`,
  `chore`. The scope is optional: a component (`button`), a core part (`scenes`,
  `actions`), or `site`, `icons`, `skills`, `devtools`. Breaking changes add `!`
  after the type and say what breaks in the body.
- Commits carry no attribution trailers (no `Co-Authored-By`, no session links);
  attribution is handled at the project level.
