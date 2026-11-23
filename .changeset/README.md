# Changesets

Run `pnpm changeset` to describe a change to a published npm package
(`@goatsoft/lucy-icons`, `@goatsoft/lucy-mcp`). On main, the release workflow opens a "Version
Packages" PR; merging it publishes to npm with provenance and creates the
GitHub Release. The Luau package is not versioned here: it ships on Wally.
