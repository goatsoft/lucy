# 0012: One repo for the package and its website; only the package ships

- Status: accepted
- Date: 2026-10-30

## Context

Lucy will have a website that hosts its documentation. The same setup already
works in Aurora: a pnpm workspace with published packages, a private `apps/site`
(Vue, Vite, prerendered) that reads the root `docs/` Markdown into `/docs/...`
routes, decision records kept repo-only with links to GitHub, and a Pages
workflow that deploys the site from `main`.

Lucy's package is Luau, not npm, and Rojo, Wally and the copy-in CLI all expect
it at the repository root.

## Decision

- Keep the Luau package at the root (`src/`, `default.project.json`, `wally.toml`).
- Add the website as `apps/site`, a private pnpm workspace app following Aurora's
  layout. The root `docs/` folder stays the single source of the docs: the site
  renders it, GitHub renders it, and agents read it. `docs/adr` is not published
  on the site; links to ADRs point at GitHub.
- The site may also serve `registry.json` so the CLI can install from a URL later.
- Distribution is the package only:
  - The Wally package may contain only `src/` (minus specs and `src/Testing`),
    `default.project.json`, `wally.toml`, `README.md` and `LICENSE`. Wally 0.3
    ignores `include`, so `wally.toml` uses an exclude list, and CI checks
    `wally package --list` against that allow-list, so anything new that leaks
    in fails the build.
  - The copy-in CLI only copies files listed in `registry.json`, all under `src/`.
  - Deploying the site is a separate workflow and never publishes the package.

## Consequences

- A component change and its docs land in one pull request.
- Node tooling (pnpm, Vite) appears in the repo but is confined to `apps/` and a
  few root workspace files; Luau contributors can ignore it.
- CI runs Luau checks and site checks as separate jobs, filtered by path.

## Alternatives considered

- **Separate site repo** pulling `docs/` at build time: cleaner split, but docs
  and code drift and every change needs two pull requests.
