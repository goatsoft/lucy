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
- Code and docs do not name third-party design systems or CSS frameworks; ADRs may.
- Scratch files go outside the repo (e.g. `/tmp`).
- Only the Luau package ships. The website (`apps/site`, `libs/`) is never part of it;
  a new top-level path must be added to `wally.toml`'s `exclude` (CI checks).
- `libs/gruff` is a temporary copy of Aurora's gruff (ADR 0012); fix bugs in both or not at all.
- Tests run in the Lucy dev place Studio window only, never a game's:
  `require(game.ReplicatedStorage.LucyTests.Runner).run()`. JB serves Rojo himself (port 38574).
- Shell commands on JB's Mac run through zsh: `zsh -lc "cd ~/Projects/Lucy && ..."`.
- Format before committing: `stylua src tests scripts examples` (CI runs `stylua --check`).
- Commits carry no attribution trailers (no `Co-Authored-By`, no session links);
  attribution is handled at the project level.
