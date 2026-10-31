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
  layout. JS workspace packages live in `libs/`, not `packages/`: macOS is
  case-insensitive, so `packages/` would be the same folder as Wally's `Packages/`. The root `docs/` folder stays the single source of the docs: the site
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

## The docs engine (gruff)

The site is built with gruff, Aurora's Markdown-to-Vue static site generator.
gruff is private to the Aurora repo, so for now `libs/gruff` is a copy of it
(minus Aurora's live-demo fence). Two copies drift, so this is temporary:

- **Follow-up:** publish gruff as a GOATsoft package (`@goatsoft/gruff`) from
  one home, consumed by Aurora and Lucy alike. Then delete `libs/gruff` and
  depend on the published version.
- The docs layout components copied into `apps/site` (DocPage, DocToc,
  SearchDialog, CodeGroup, CopyButton, Term) are the same kind of duplicate and
  should ship with that package (for example as `@goatsoft/gruff/vue`).
- **Done (November 2026):** `@goatsoft/gruff` 0.1.0 is on npm with the docs
  components in `@goatsoft/gruff/vue`. The site depends on it; `libs/gruff`
  and the copied components are gone.

## Consequences

- A component change and its docs land in one pull request.
- Node tooling (pnpm, Vite) appears in the repo but is confined to `apps/` and a
  few root workspace files; Luau contributors can ignore it.
- CI runs Luau checks and site checks as separate jobs, filtered by path.

## Alternatives considered

- **Separate site repo** pulling `docs/` at build time: cleaner split, but docs
  and code drift and every change needs two pull requests.
