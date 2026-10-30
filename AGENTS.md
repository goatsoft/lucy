# AGENTS.md

Start with [README.md](README.md); it links to the architecture, component and
development docs. Read the relevant ADRs in `docs/adr/` before changing structure,
and add a new ADR for any structural decision.

Rules:

- Never use the em-dash character anywhere (code, comments, docs, commits).
  Check: `grep -rn $'\xe2\x80\x94' --exclude-dir=.git --exclude-dir=DevPackages .` prints nothing.
- TDD: write the `*.spec.luau` first, see it fail, then implement.
- Looks belong in style rules with `$Token` values; code sets behaviour and layout only.
- Components keep state in AppState at `ui.<id>` and work with mouse, keyboard, gamepad and touch.
- Code and docs do not name third-party design systems or CSS frameworks; ADRs may.
- Scratch files go outside the repo (e.g. `/tmp`).
- Tests run in the Lucy dev place Studio window only, never a game's:
  `require(game.ReplicatedStorage.LucyTests.Runner).run()`. JB serves Rojo himself (port 38574).
